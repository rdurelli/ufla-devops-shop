# Analise de access.log -- Lucas Gabriel Pereira Moreira (@lucasgpmoreira)

**Linhas analisadas:** 516866

```bash
wc -l dados/access.log
```

```
516866 dados/access.log
```

## 1. Volume e falha

```bash
awk '{print $9}' dados/access.log | sort | uniq -c | sort -rn
```

```
 498955 200
   6900 503
   4849 500
   4501 404
   1661 403
```

**Leitura:** O log tem 516.866 requisições. Pelo campo de status, os 4xx somam 4.501 + 1.661 = 6.162 (1,19%) e os 5xx somam 6.900 + 4.849 = 11.749 (2,27%). A proporção está invertida em relação a um servidor saudável: quase o dobro de erro de servidor do que de cliente, e o 503 sozinho supera todos os 4xx. O 503 é falta de capacidade, não defeito de código, e isso já aponta para sobrecarga.

A contagem foi feita pelo campo `$9`, e não por texto solto na linha. A diferença é mensurável:

```bash
grep -c ' 500 ' dados/access.log
```

```
4921
```

```bash
awk '$9 == 500 {print $9}' dados/access.log | wc -l
```

```
4849
```

São 72 linhas a mais no `grep`: requisições bem-sucedidas cujo tamanho de resposta (`$10`) era 500 bytes. O `grep` não sabe o que é coluna; o `awk` sabe.

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

O primeiro tem quase 50 vezes o volume do segundo, enquanto do segundo ao décimo a variação é de 2%. Essa quebra de escala justifica investigar só ele. O que pedia:

```bash
grep '^203.0.113.47 ' dados/access.log | awk '{print $7}' | sort | uniq -c | sort -rn
```

```
  22224 /api/busca?q=mochila
  22161 /api/busca?q=tenis
  22090 /api/busca?q=camiseta
  21925 /api/busca?q=fone
```

Com que cliente:

```bash
grep '^203.0.113.47 ' dados/access.log | cut -d'"' -f6 | sort | uniq -c | sort -rn
```

```
  88400 curl/8.5.0
```

Em que ritmo:

```bash
grep '^203.0.113.47 ' dados/access.log | awk '{print $4}' | cut -d: -f2 | sort | uniq -c
```

```
  30940 22
  57460 23
```

E o que recebeu de volta:

```bash
grep '^203.0.113.47 ' dados/access.log | awk '{print $9}' | sort | uniq -c | sort -rn
```

```
  81500 200
   6900 503
```

**Leitura:** É um raspador, não um usuário, e três evidências apontam para isso. O repertório: 88.400 requisições em quatro termos de busca, cerca de 22 mil vezes cada — gente real não busca "mochila" 22.224 vezes. O cliente: `curl/8.5.0` em 100% delas e nenhum acesso a `/static/`, sendo que navegador puxa CSS e JavaScript junto. O ritmo: tudo em duas horas, 57.460 na hora 23, cerca de 16 por segundo. O que fecha o caso é o último pipeline: os 6.900 erros 503 que ele recebeu são todos os 503 do log.

## 3. O endpoint quebrado

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

Para saber se quebra sempre ou às vezes, o total daquele caminho:

```bash
awk '$7 == "/api/relatorio/gerar" {print $9}' dados/access.log | sort | uniq -c | sort -rn
```

```
   6780 200
   3620 500
```

**Leitura:** O caminho `/api/relatorio/gerar` concentra 3.620 dos 4.849 erros 500, 75% do total. Não quebra sempre: de 6.780 + 3.620 = 10.400 requisições, falhou em 3.620, taxa de 34,8%. Falhar em um terço das chamadas sugere disputa por recurso, timeout ou limite de memória conforme o tamanho do relatório — código simplesmente quebrado derrubaria as 10.400.

## 4. A hora do pico

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

**Leitura:** A curva é de uso humano normal até as 21h: vale de madrugada perto de 1.500 por hora, subida a partir das 7h, platô em torno de 30 mil entre 10h e 18h, queda para 15.577 às 21h. Então o padrão se rompe, com 43.979 às 22h e 68.535 às 23h, quatro vezes e meia a hora anterior. Não é sazonalidade, porque contraria a curva do próprio dia: o tráfego estava caindo e voltou a subir tarde da noite. Cruzando com o ritmo do IP da pergunta 2, ele responde por 70% e 84% dessas duas horas — o pico e o raspador são o mesmo evento.

## 5. Alguem batendo na porta

```bash
awk '{print $7}' dados/access.log | grep -E '^/(admin|\.env|\.git|wp-login|phpmyadmin)' | sort | uniq -c | sort -rn
```

```
    382 /admin/login
    368 /wp-login.php
    356 /.git/config
    343 /.env
    318 /phpmyadmin/index.php
    313 /admin
```

Quantas ao todo:

```bash
awk '{print $7}' dados/access.log | grep -cE '^/(admin|\.env|\.git|wp-login|phpmyadmin)'
```

```
2080
```

De quantos IPs distintos:

```bash
awk '{print $1, $7}' dados/access.log | grep -E ' /(admin|\.env|\.git|wp-login|phpmyadmin)' | awk '{print $1}' | sort | uniq -c | sort -rn
```

```
   1053 198.51.100.9
   1027 198.51.100.23
```

E o que o servidor respondeu:

```bash
awk '{print $9, $7}' dados/access.log | grep -E ' /(admin|\.env|\.git|wp-login|phpmyadmin)' | awk '{print $1}' | sort | uniq -c | sort -rn
```

```
   2080 404
```

**Leitura:** São 2.080 tentativas de apenas 2 IPs, e o servidor respondeu 404 em todas. A lista é um dicionário genérico de varredura: `/wp-login.php` e `/phpmyadmin/index.php` nem existem nesta aplicação, o que indica robô testando alvos comuns e não alguém que estudou este sistema. Os dois IPs dividem o trabalho quase igualmente, 1.053 contra 1.027. O que merece atenção são `/.env` e `/.git/config`, 699 tentativas somadas: se um dia responderem 200 por um deslize de configuração, entregam credenciais e código-fonte de uma vez.

## Conclusao: minha primeira acao como operador de plantao

Minha primeira ação seria limitar a taxa do IP 203.0.113.47 no Nginx, e não bloquear a aplicação inteira nem reverter versão. Os dados ligam três sintomas a uma causa só: esse IP é 84% do tráfego da hora do pico, faz 16 requisições por segundo com `curl`, e recebeu todos os 6.900 erros 503 do log. Como 503 é falta de capacidade e não defeito, cortar essa origem devolve capacidade na hora, com risco baixo, porque nenhum usuário legítimo tem esse perfil. Faria por taxa e não por IP fixo, já que raspador troca de endereço com facilidade. O `/api/relatorio/gerar`, com 34,8% de falha, é mais grave para o produto, mas falha igual às 3h da manhã: vai para o time responsável pela manhã, com os números na mão, não para a madrugada. A varredura levou 404 nas 2.080 tentativas e também pode esperar o horário comercial, virando regra de bloqueio permanente.
