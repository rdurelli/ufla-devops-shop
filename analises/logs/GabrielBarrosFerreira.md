# Analise de access.log -- Gabriel Barros Ferreira (@GabrielBarrosFerreira)

**Linhas analisadas:** 516866

## 1. Volume e falha

```bash
awk '$9 ~ /^4/ {c4++} $9 ~ /^5/ {c5++} END {printf "4xx: %d (%.2f%%)\n5xx: %d (%.2f%%)\ntotal: %d\n", c4, c4/NR*100, c5, c5/NR*100, NR}' dados/access.log
```

```
4xx: 6162 (1.19%)
5xx: 11749 (2.27%)
total: 516866
```

**Leitura:** De 516.866 requisições, 6.162 falharam com 4xx (1,19%) e 11.749 com 5xx (2,27%), somando 3,46% de falhas. O que chama atenção é que os erros de servidor (5xx) são quase o dobro dos de cliente (4xx) -- normalmente é o contrário. Isso indica que o problema está mais do lado do servidor do que em requisições malformadas dos clientes.

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

O IP `203.0.113.47` é claramente suspeito: sozinho fez 88.400 requisições, quase 50x mais que o segundo colocado (1.788). Todos os demais IPs ficam na faixa de 1.750 a 1.790, um comportamento uniforme de tráfego normal -- só o primeiro destoa. Investigando o que ele pedia e com qual user-agent:

```bash
grep '^203.0.113.47 ' dados/access.log | awk '{print $7}' | sort | uniq -c | sort -rn | head
grep '^203.0.113.47 ' dados/access.log | awk -F'"' '{print $6}' | sort | uniq -c | sort -rn
```

```
  22224 /api/busca?q=mochila
  22161 /api/busca?q=tenis
  22090 /api/busca?q=camiseta
  21925 /api/busca?q=fone

  88400 curl/8.5.0
```

**Leitura:** Todas as 88.400 requisições foram no endpoint `/api/busca`, distribuídas quase igualmente entre quatro termos de busca, e 100% delas usando o user-agent `curl/8.5.0`. Isso não é um usuário humano navegando -- é um script automatizado martelando o endpoint de busca. Nenhum navegador real faz 88 mil buscas com curl e um punhado de termos repetidos. É um IP hostil sobrecarregando a busca.

## 3. O endpoint que mais deu erro 500

```bash
awk '$9 == 500 {print $7}' dados/access.log | sort | uniq -c | sort -rn | head
```

```
   3620 /api/relatorio/gerar
    228 /
    167 /api/produtos
    160 /produtos
    150 /produtos/detalhe
    117 /static/app.css
    105 /static/app.js
     92 /api/carrinho
     63 /api/busca
     44 /favicon.ico
```

O `/api/relatorio/gerar` domina os erros 500, com 3.620 ocorrências -- mais de 15x o segundo colocado. Comparando o total desse caminho com quantos deram 500:

```bash
awk '$7 == "/api/relatorio/gerar" {total++; if ($9==500) erros++} END {printf "total: %d\n500: %d\ntaxa: %.1f%%\n", total, erros, erros/total*100}' dados/access.log
```

```
total: 10400
500: 3620
taxa: 34.8%
```

**Leitura:** O endpoint não quebra sempre, mas falha em 34,8% das chamadas -- cerca de 1 a cada 3. Uma falha intermitente nessa proporção aponta para um problema sob carga (timeout, esgotamento de recurso ou dependência instável na geração do relatório), não para um bug determinístico que quebraria 100% das vezes.

## 4. A hora do pico

```bash
awk '{print $4}' dados/access.log | cut -d: -f2 | sort | uniq -c | sort -k2 -n
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

**Leitura:** O pico absoluto é às 23h, com 68.535 requisições, seguido das 22h com 43.979. Durante o dia o tráfego segue um padrão comercial saudável (madrugada baixa, subida pela manhã, platô de ~30 mil entre 10h e 16h, queda à noite). Mas às 22h e 23h há um salto anormal, fora da curva natural -- justamente o horário em que o servidor ficou lento. Esse pico coincide com a atividade do IP `203.0.113.47`.

## 5. Alguem batendo na porta

```bash
grep -E '/admin|\.env|\.git|wp-login|/phpmyadmin' dados/access.log | wc -l
grep -E '/admin|\.env|\.git|wp-login|/phpmyadmin' dados/access.log | awk '{print $1}' | sort -u | wc -l
grep -E '/admin|\.env|\.git|wp-login|/phpmyadmin' dados/access.log | awk '{print $9}' | sort | uniq -c | sort -rn
```

```
2080
2
   2080 404
```

**Leitura:** Houve 2.080 tentativas de acesso a caminhos sensíveis, vindas de apenas 2 IPs distintos, e o servidor respondeu 404 a todas elas. É uma varredura de reconhecimento hostil (alguém procurando `/admin`, `.env`, `.git`, etc.), mas sem sucesso -- nenhum desses caminhos existe ou está exposto. Não houve comprometimento por essa via, embora a tentativa em si mereça registro e monitoramento.

## Conclusao: minha primeira acao como operador de plantao

Minha primeira ação seria **bloquear o IP `203.0.113.47`** no firewall (ou aplicar rate limiting imediato sobre ele). A justificativa está nos dados: esse único IP responde por 88.400 das 516.866 requisições -- cerca de 17% de todo o tráfego do log -- e está concentrado no `/api/busca` com padrão claramente automatizado (curl, termos repetidos). O pico de tráfego das 22h e 23h, exatamente quando o servidor ficou lento, coincide com essa atividade. Bloquear esse IP é a ação de maior impacto e menor risco: alivia a carga na hora, sem afetar usuários legítimos (que estão na faixa de ~1.800 requisições). Em seguida, eu escalaria a investigação do `/api/relatorio/gerar`, cujos 34,8% de erro 500 são um problema real de estabilidade, mas que não é a causa da lentidão aguda desta madrugada -- esse é um trabalho para o dia seguinte, não para o plantão.