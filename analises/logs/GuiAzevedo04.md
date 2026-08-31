# Análise do access.log

**Autor:** Guilherme Luiz de Azevedo [@GuiAzevedo04](https://github.com/GuiAzevedo04)
**Arquivo analisado:** `dados/access.log`, 516.866 linhas, trazido com `./scripts/baixar-dados.sh`

Antes de escrever qualquer pipeline rodei um `head -3` pra saber com que campos eu estava
lidando. O campo 1 é o IP, o 4 tem a data e a hora, o 7 é o endpoint e o 9 é o status. Tudo
que vem abaixo depende disso.

## 1. Quantas requisições houve, e quantas falharam

```bash
wc -l < dados/access.log
```

```
516866
```

```bash
awk '{print $9}' dados/access.log | cut -c1 | sort | uniq -c | sort -rn
```

```
 498955 2
  11749 5
   6162 4
```

Foram 516.866 requisições, sendo 6.162 com erro 4xx e 11.749 com erro 5xx. Somando as duas
faixas, cerca de 3,5% do tráfego falhou. O que me chamou atenção aqui é ter quase o dobro de
erro de servidor em relação a erro de cliente, o normal seria o contrário, e isso já indicava
que tinha alguma coisa quebrando do lado de dentro.

## 2. Os 10 IPs mais frequentes

```bash
awk '{print $1}' dados/access.log | sort | uniq -c | sort -rn | head -10
```

```
  88400 203.0.113.47
   1788 192.0.2.245
   1772 192.0.2.171
   1771 192.0.2.81
   1771 192.0.2.225
   1771 192.0.2.16
   1767 192.0.2.138
   1762 192.0.2.222
   1757 192.0.2.45
   1753 192.0.2.166
```

O 203.0.113.47 é claramente suspeito. Ele sozinho fez 88.400 requisições enquanto o segundo
colocado fez 1.788, ou seja quase 50 vezes mais que o resto da lista, e todos os outros nove
estão na mesma faixa de 1.700 e poucos, que é o que parece ser um usuário normal nesse log.

Só o volume já bastaria pra desconfiar, mas fui ver o que ele estava pedindo:

```bash
grep '^203.0.113.47' dados/access.log | awk '{print $7}' | sort | uniq -c | sort -rn
```

```
  22224 /api/busca?q=mochila
  22161 /api/busca?q=tenis
  22090 /api/busca?q=camiseta
  21925 /api/busca?q=fone
```

Quatro URLs apenas, sempre a mesma busca, divididas quase igualmente entre elas. Gente de
verdade não navega assim: não carrega imagem, não carrega CSS, não entra em outra página e não
repete a mesma consulta 22 mil vezes. Isso é script em laço.

## 3. Qual endpoint causou mais erro 500

```bash
awk '$9 == 500 {print $7}' dados/access.log | sort | uniq -c | sort -rn | head -5
```

```
   3620 /api/relatorio/gerar
    228 /
    167 /api/produtos
    160 /produtos
    150 /produtos/detalhe
```

O `/api/relatorio/gerar` responde por 3.620 dos 4.849 erros 500 do log inteiro, os outros
endpoints estão todos na casa das centenas. É um problema isolado daquela rota e não uma
instabilidade geral da aplicação.

Aproveitei pra olhar os outros 5xx, já que na pergunta 1 os erros de servidor tinham dado alto
demais:

```bash
awk '$9 >= 500 {print $9}' dados/access.log | sort | uniq -c | sort -rn
```

```
   6900 503
   4849 500
```

Tem mais 503 do que 500, e o 503 aparece justamente nas quatro URLs de busca que o
203.0.113.47 estava martelando. Ou seja o servidor ficou indisponível porque não deu conta do
volume que aquele IP jogou nele.

## 4. Hora do pico de tráfego

```bash
awk '{print $4}' dados/access.log | cut -d: -f2 | sort | uniq -c
```

```
   3262 00
   1967 01
   1810 02
   1471 03
   1498 04
   1844 05
   3904 06
   9759 07
  19519 08
  27621 09
  30869 10
  32526 11
  31895 12
  29952 13
  31225 14
  32529 15
  30886 16
  28575 17
  25996 18
  22807 19
  18860 20
  15577 21
  43979 22
  68535 23
```

O pico é às 23h, com 68.535 requisições. Só que o resto da curva não faz sentido nenhum com
isso: o tráfego sobe de manhã, fica estável em uns 30 mil entre 10h e 16h, começa a cair à
tarde e desaba pra 15 mil às 21h. Aí do nada dobra às 22h e quase quintuplica às 23h. Refiz a
conta tirando o IP suspeito:

```bash
grep -v '^203.0.113.47' dados/access.log | awk '{print $4}' | cut -d: -f2 | sort | uniq -c | sort -rn | head -4
```

```
  32529 15
  32526 11
  31895 12
  31225 14
```

Sem ele o pico passa a ser às 15h e as 23h cai pra 11.075, que é um valor coerente com o
horário. Então a resposta honesta é que o pico das 23h não é tráfego de usuário, é o flood.

## 5. Tentativa de acesso a caminho sensível

```bash
awk '{print $7}' dados/access.log | grep -iE '/admin|\.env|\.git' | sort | uniq -c | sort -rn
```

```
    382 /admin/login
    356 /.git/config
    343 /.env
    313 /admin
```

Tem sim, 1.394 tentativas. O `.git/config` e o `.env` são os dois casos clássicos que a aula
citou, quem pede esses arquivos está procurando credencial exposta e não usando o site. Fui
ver de onde vinham:

```bash
awk '{print $1, $7}' dados/access.log | grep -iE '/admin|\.env|\.git' | awk '{print $1}' | sort | uniq -c | sort -rn
```

```
    700 198.51.100.9
    694 198.51.100.23
```

Dois IPs só, dividindo o trabalho quase pela metade, o que reforça que é ferramenta automática
e não alguém clicando. E o detalhe que eu achei mais interessante do relatório inteiro: esses
dois fizeram 1.053 e 1.027 requisições no total, ficando logo abaixo do décimo colocado da
pergunta 2, que tinha 1.753. Eles não aparecem no top 10. Se eu tivesse parado na pergunta 2 e
olhado só o ranking de volume, o scanner passaria batido, enquanto o flood, que é barulhento,
salta aos olhos na primeira linha.

Uma boa notícia pra fechar:

```bash
awk '{print $7, $9}' dados/access.log | grep -iE '/admin|\.env|\.git' | awk '{print $2}' | sort | uniq -c
```

```
   1394 404
```

As 1.394 tentativas voltaram 404, nenhuma delas achou nada. O servidor não entregou arquivo
nenhum, mas as tentativas continuam registradas e valeria bloquear esses dois IPs.
