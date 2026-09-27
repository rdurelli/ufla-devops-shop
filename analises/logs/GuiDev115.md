# Analise de access.log -- Guilherme Fabricio (@GuiDev115)

**Linhas analisadas:** 516866

## 1. Volume e falha

```bash
# Total de requisições
wc -l dados/access.log

# Requisições com status 4xx
awk '$9 >= 400 && $9 < 500' dados/access.log | wc -l

# Requisições com status 5xx
awk '$9 >= 500 && $9 < 600' dados/access.log | wc -l
```

```
516866 dados/access.log
6162
11749
```

**Leitura:** O log contém 516.866 requisições no total. Erros 4xx somam 6.162 (≈1,19% do total) e erros 5xx somam 11.749 (≈2,27%), totalizando ≈3,46% de falhas. O volume de 5xx supera o de 4xx, o que é preocupante pois indica problemas no servidor, não apenas erros de cliente.

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

### Investigação do IP suspeito: 203.0.113.47

```bash
# Endpoints mais acessados
awk '$1 == "203.0.113.47" {print $7}' dados/access.log | sort | uniq -c | sort -rn | head -10

# User-agent
awk '$1 == "203.0.113.47" {print $NF}' dados/access.log | sort | uniq -c | sort -rn | head -5

# Status codes
awk '$1 == "203.0.113.47" {print $9}' dados/access.log | sort | uniq -c | sort -rn

# Distribuição por hora
awk '$1 == "203.0.113.47" {print $4}' dados/access.log | cut -d: -f2 | sort | uniq -c | sort -k2 -n
```

```
# Endpoints:
  22224 /api/busca?q=mochila
  22161 /api/busca?q=tenis
  22090 /api/busca?q=camiseta
  21925 /api/busca?q=fone

# User-agent:
  88400 "curl/8.5.0"

# Status codes:
  81500 200
   6900 503

# Por hora:
  30940 22
  57460 23
```

**Leitura:** O IP 203.0.113.47 fez 88.400 requisições — 49x mais que o segundo colocado — concentradas em apenas 2 horas (22h e 23h), todas via `curl/8.5.0` sem qualquer browser real. Acessa repetidamente apenas 4 endpoints de busca com parâmetros fixos (`mochila`, `tenis`, `camiseta`, `fone`), padrão claro de scraping ou bot automatizado. Gerou 6.900 erros 503 (servidor sobrecarregado), confirmando que o volume causou impacto real no serviço.

## 3. O endpoint quebrado

```bash
# Endpoint com mais 500
awk '$9 == 500 {print $7}' dados/access.log | sort | uniq -c | sort -rn | head -10

# Total de requisições e 500 para o endpoint líder
awk '$7 == "/api/relatorio/gerar" {count++} END {print "Total:", count}' dados/access.log
awk '$7 == "/api/relatorio/gerar" && $9 == 500 {count++} END {print "500s:", count}' dados/access.log
```

```
# Top endpoints com 500:
   3620 /api/relatorio/gerar
    228 /
    167 /api/produtos
    160 /produtos
    150 /produtos/detalhe

# Proporção:
Total: 10400
500s: 3620
```

**Leitura:** O endpoint `/api/relatorio/gerar` é o mais problemático, com 3.620 erros 500 em 10.400 requisições — uma taxa de falha de **34,8%**. Isso indica que o endpoint não quebra sempre (falha em ~1 a cada 3 tentativas), sugerindo um bug intermitente: possivelmente timeout, falha de recurso externo ou condição de corrida sob carga.

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

**Leitura:** O tráfego orgânico segue um padrão comercial típico — cresce a partir das 07h, mantém platô entre 10h–17h (~30k req/hora) e declina à noite. Porém, às 22h–23h há um pico anômalo que ultrapassa todo o período diurno (43.979 e 68.535 req/hora respectivamente), causado pelo bot 203.0.113.47, que distorce completamente a curva natural.

## 5. Alguém batendo na porta

```bash
# Total de acessos a caminhos sensíveis
awk '$7 ~ /(\/admin|\.env|\.git|wp-login|\/phpmyadmin)/' dados/access.log | wc -l

# IPs distintos
awk '$7 ~ /(\/admin|\.env|\.git|wp-login|\/phpmyadmin)/ {print $1}' dados/access.log | sort -u | wc -l

# Quais IPs
awk '$7 ~ /(\/admin|\.env|\.git|wp-login|\/phpmyadmin)/ {print $1}' dados/access.log | sort -u

# Resposta do servidor
awk '$7 ~ /(\/admin|\.env|\.git|wp-login|\/phpmyadmin)/ {print $9}' dados/access.log | sort | uniq -c | sort -rn

# Detalhes por caminho
awk '$7 ~ /(\/admin|\.env|\.git|wp-login|\/phpmyadmin)/ {print $7}' dados/access.log | sort | uniq -c | sort -rn
```

```
# Total:
2080

# IPs distintos:
2

# Quais IPs:
198.51.100.23
198.51.100.9

# Resposta do servidor:
   2080 404

# Por caminho:
    382 /admin/login
    368 /wp-login.php
    356 /.git/config
    343 /.env
    318 /phpmyadmin/index.php
    313 /admin
```

**Leitura:** Dois IPs (198.51.100.23 e 198.51.100.9) fizeram 2.080 tentativas de acesso a caminhos sensíveis, varrendo sistematicamente `/admin`, `.env`, `.git/config`, `wp-login.php` e `/phpmyadmin` — padrão clássico de reconhecimento automatizado (scanner de vulnerabilidades). O servidor respondeu 404 em 100% dos casos, o que é bom: nenhum dos caminhos existe. Ainda assim, a atividade representa uma varredura ativa de segurança e merece bloqueio preventivo.

## Conclusao: minha primeira acao como operador de plantao

Minha primeira ação seria **bloquear imediatamente o IP 203.0.113.47 no firewall** (via `iptables` ou regra no Nginx com `deny 203.0.113.47`). Os dados mostram que esse único IP sozinho gerou 88.400 requisições em 2 horas, causou 6.900 erros 503 — sobrecarregando o serviço para usuários reais — e criou o pico anômalo das 22h–23h. Como segunda prioridade, adicionaria os dois IPs de reconhecimento (198.51.100.23 e 198.51.100.9) à lista de bloqueio e acionaria o time de desenvolvimento sobre o `/api/relatorio/gerar`, que falha 34,8% das vezes e pode estar sendo agravado pela carga do bot.
