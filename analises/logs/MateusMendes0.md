# Análise de access.log — Mateus Mendes da Silva (@MateusMendes0)

**Linhas analisadas:** 2880

## 1. Volume e falha

```bash
wc dados/access.log 
```

```
Total de logs : 516866
```
ERROS 500
```bash
awk '$9 ~ /^5../' dados/access.log | wc -l
```

```
11749
```

ERROS 400
```bash
awk '$9 ~ /^4../' dados/access.log | wc -l
```

```
6162
```

Isso representa cerca de 3.46% dos logs com erros 400 ou 500.


**Leitura:** <uma ou duas frases>

## 2. Os 10 IPs mais frequentes

```bash
awk '{print $1}' dados/access.log | sort | uniq -c | sort -nr | head -n 10

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
   1753 192.0.2.16
```




**Leitura:** O IP de maior frequência é o 203.0.113.47, com 88400 requisições, o que representa cerca de 17% do total. Os outros IPs aparecem com frequência bem menor.

```
 awk '$1 == "203.0.113.47" {print $7}' dados/access.log | sort | uniq -c
```

```
  22090 /api/busca?q=camiseta
  21925 /api/busca?q=fonent
  22224 /api/busca?q=mochila
  22161 /api/busca?q=tenist
  22050 /api/busca?q=jaqueta
```

Esse IP realizou milhares de buscas na API, buscando diversas palavras como "camiseta", "fone", "mochila", "tênis", "jaqueta"

O mais estranho foi o seu User-agent, fazendo requisições curl.O que indica um provável ataque de força bruta através de scripts provavelmente. 

```bash
awk '$1 == "203.0.113.47" {print $12}' dados/access.log | sort | uniq -c
  88400 "curl/8.5.0"
```

## 3. O endpoint quebrado

```bash
awk '$9 == "500" {print $7}' dados/access.log | sort | uniq -c | sort -nr | head -n 10
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

**Leitura:** O endpoint /api/relatorio/gerar é o que mais gera erros 500, com 3620 ocorrências. Isso representa cerca de 30% dos erros 500.


```bash
awk '$7 == "/api/relatorio/gerar" {print $9}' dados/access.log | sort | uniq -c
   6780 200
   3620 500
```

## 4. A hora do pico

```bash
awk -F: '{print $2}' dados/access.log | sort | uniq -c
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

**Leitura:** O horário de pico é às 23:00, com 68535 requisições.

## 5. Alguém batendo na porta

```bash
grep -E '(/admin|\.env|\.git|wp-login|phpmyadmin)' dados/access.log | awk '{print $7}' | sort | uniq -c | sort -nr
```

```
    382 /admin/login
    368 /wp-login.php
    356 /.git/config
    343 /.env
    318 /phpmyadmin/index.php
    313 /admin
```

```bash
grep -E '(/admin|\.env|\.git|wp-login|phpmyadmin)' dados/access.log | awk '{print $1}' | sort | uniq -c

```

```
   1027 198.51.100.23
   1053 198.51.100.9
```


```bash
grep -E '(/admin|\.env|\.git|wp-login|phpmyadmin)' dados/access.log | awk '{print $9}' | sort | uniq -c
   
```

```
2080 404
```

**Leitura:** Os IPs 198.51.100.23 e 198.51.100.9 são os que mais tentam acessar os endpoints protegidos, com 1027 e 1053 requisições respectivamente. Os principais alvos são /admin/login e /wp-login.php.O servidor respondeu 404 (Not Found) para 100% das tentativas, indicando que nenhuma dessas rotas existe ou foi exposta.

## Conclusão

Minha primeira ação imediata seria bloquear no Firewall/WAF o IP 203.0.113.47 e, preventivamente, os IPs 198.51.100.9 e 198.51.100.23.

Justificativa: O IP 203.0.113.47 respondeu sozinho por 88.400 requisições (mais de 17% de toda a carga do sistema) realizando um ataque automatizado/scraping intenso na rota /api/busca com o User-Agent curl/8.5.0, sobrecarregando a infraestrutura. Além disso, os IPs 198.51.100.9 e 198.51.100.23 realizaram mais de 2.000 tentativas de varredura contra arquivos e caminhos sensíveis (/.env, /.git, /admin) usando python-requests. Como ação secundária realizaria uma investigação no backend para investigar a taxa de falha de ~35% (3.620 erros 500) na rota /api/relatorio/gerar.

