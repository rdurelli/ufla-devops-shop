# Análise de access.log -- João Victor de Morais Reis (@jvmoraisreis18)

**Linhas analisadas:** 516866

## 1. Volume e falha

```bash
awk '
$9 ~ /^4/ {c4++}
$9 ~ /^5/ {c5++}
END {
    total = c4 + c5
    printf "4xx: %d (%.2f%%)\n", c4, c4/NR*100
    printf "5xx: %d (%.2f%%)\n", c5, c5/NR*100
    printf "Total de falhas: %d (%.2f%%)\n", total, total/NR*100
}' dados/access.log
```

```text
4xx: 6162 (1,19%)
5xx: 11749 (2,27%)
Total de falhas: 17911 (3,47%)
```

**Leitura:** O log possui 516.866 requisições, das quais 17.911 resultaram em respostas 4xx ou 5xx, representando 3,47% do total. As respostas 5xx correspondem a 2,27%, enquanto as 4xx representam 1,19%.

## 2. Os 10 IPs mais frequentes

```bash
awk '{print $1}' dados/access.log | sort | uniq -c | sort -rn | head -10
```

```text
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

**Leitura:** O IP `203.0.113.47` apresenta comportamento discrepante, com 88.400 requisições, enquanto os demais IPs do top 10 ficaram próximos de 1.750 a 1.800 requisições.

Para investigar o IP suspeito, foram analisados os caminhos requisitados:

```bash
awk '$1 == "203.0.113.47" {print $7}' dados/access.log | sort | uniq -c | sort -rn | head -20
```

```text
22224 /api/busca?q=mochila
22161 /api/busca?q=tenis
22090 /api/busca?q=camiseta
21925 /api/busca?q=fone
```

O período de atuação foi verificado com:

```bash
awk '$1 == "203.0.113.47" {print $4}' dados/access.log | sort | head -1
```

```text
[14/Aug/2026:22:00:00
```

```bash
awk '$1 == "203.0.113.47" {print $4}' dados/access.log | sort | tail -1
```

```text
[14/Aug/2026:23:59:59
```

O user-agent utilizado foi identificado por:

```bash
awk '$1 == "203.0.113.47" {print $12}' dados/access.log | sort | uniq -c | sort -rn
```

```text
88400 "curl/8.5.0"
```

Também foram verificadas as respostas recebidas:

```bash
awk '$1 == "203.0.113.47" {print $9}' dados/access.log | sort | uniq -c | sort -rn
```

```text
81500 200
 6900 503
```

**Leitura:** O IP `203.0.113.47` é o principal candidato a comportamento suspeito, pois realizou 88.400 requisições em duas horas, aproximadamente 12,3 requisições por segundo, enquanto os demais IPs do top 10 ficaram próximos de 1.700 requisições. As requisições ficaram concentradas em quatro consultas ao `/api/busca` e utilizaram exclusivamente o user-agent `curl/8.5.0`; além disso, 6.900 delas receberam status `503`, indicando um comportamento automatizado e anormal.

## 3. O endpoint quebrado

```bash
awk '$9 == 500 {print $7}' dados/access.log | sort | uniq -c | sort -rn | head -10
```

```text
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

Para verificar a proporção de falhas do endpoint:

```bash
awk '$7 == "/api/relatorio/gerar" {count++} END {print count}' dados/access.log
```

```text
10400
```

**Leitura:** O caminho `/api/relatorio/gerar` foi o que mais apresentou erros 500, com 3.620 ocorrências. Como foram registradas 10.400 requisições ao endpoint, os erros representam 34,81% dos acessos, indicando que o endpoint falha com frequência, mas não em todas as requisições.

## 4. A hora do pico

```bash
awk '{print $4}' dados/access.log | cut -d: -f2 | sort | uniq -c | sort -k2n
```

```text
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

**Leitura:** O maior volume de tráfego ocorreu às 23h, com 68.535 requisições, seguido pelas 22h, com 43.979. O tráfego cresce significativamente a partir das 7h e permanece elevado durante o dia, atingindo o pico no final do período analisado.

## 5. Alguém batendo na porta

```bash
awk '$7 ~ /\/admin|\.env|\.git|wp-login|\/phpmyadmin/ {print $7}' dados/access.log | sort | uniq -c | sort -rn
```

```text
382 /admin/login
368 /wp-login.php
356 /.git/config
343 /.env
318 /phpmyadmin/index.php
313 /admin
```

Para contar os IPs distintos:

```bash
awk '$7 ~ /\/admin|\.env|\.git|wp-login|\/phpmyadmin/ {print $1}' dados/access.log | sort -u | wc -l
```

```text
2
```

Para verificar as respostas do servidor:

```bash
awk '$7 ~ /\/admin|\.env|\.git|wp-login|\/phpmyadmin/ {print $9}' dados/access.log | sort | uniq -c | sort -rn
```

```text
2080 404
```

**Leitura:** Foram identificadas 2.080 tentativas de acesso a caminhos sensíveis, originadas de apenas 2 IPs distintos. Todas as tentativas receberam resposta `404`, indicando que esses caminhos não estavam disponíveis no servidor no momento dos acessos.

## Conclusão: minha primeira ação como operador de plantão

Como primeira ação, eu bloquearia temporariamente o IP `203.0.113.47` e monitoraria o comportamento do serviço. O IP realizou 88.400 requisições em apenas duas horas, utilizando exclusivamente `curl/8.5.0`, com tráfego concentrado em quatro consultas e 6.900 respostas `503`; além disso, esse período coincide com as horas de maior tráfego do log. O bloqueio temporário é uma medida concreta para reduzir imediatamente esse tráfego anormal enquanto se verifica o impacto sobre o serviço.
