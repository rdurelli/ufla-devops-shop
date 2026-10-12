# Analise de access.log -- Caio Souza (@c-souzs)
**Linhas analisadas:** 516866 (saída de `wc -l dados/access.log`)

## 1. Volume e falha
```bash
awk '{total++; if ($9 ~ /^4[0-9][0-9]$/) e4++; else if ($9 ~ /^5[0-9][0-9]$/) e5++} END {printf "total=%d 4xx=%d 5xx=%d 4xx_pct=%.2f%% 5xx_pct=%.2f%% falhas_pct=%.2f%%\n", total,e4,e5,100*e4/total,100*e5/total,100*(e4+e5)/total}' dados/access.log
```
```
total=516866 4xx=6162 5xx=11749 4xx_pct=1.19% 5xx_pct=2.27% falhas_pct=3.47%
```
**Leitura:** 17.911 requisições falharam (3,47%); 5xx predominam. A contagem usa o status no campo `$9`, não texto solto.

## 2. Os 10 IPs mais frequentes
```bash
awk '{print $1}' dados/access.log | sort | uniq -c | sort -nr | head -10
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
```bash
awk -F'"' '$1 ~ /^203\.0\.113\.47 / {print $6}' dados/access.log | sort | uniq -c | sort -nr
awk '$1=="203.0.113.47" {split($4,a,":"); print a[2]}' dados/access.log | sort | uniq -c
```
```
88400 curl/8.5.0
22 22
57460 23
```
**Leitura:** `203.0.113.47` é suspeito: concentra 88.400 acessos, usa só `curl/8.5.0` e fez 57.460 pedidos às 23h. Repetiu quase exclusivamente buscas por mochila, tenis, camiseta e fone, padrão automatizado.

## 3. O endpoint quebrado
```bash
awk '$9==500 {print $7}' dados/access.log | sort | uniq -c | sort -nr | head
awk '$7=="/api/relatorio/gerar" {total++; status[$9]++} END {for(s in status) print s,status[s]; print "total",total}' dados/access.log
```
```
3620 /api/relatorio/gerar
total 10400
200 6780
500 3620
```
**Leitura:** `/api/relatorio/gerar` lidera os 500. Falha em 34,81% das 10.400 requisições, portanto é intermitente (65,19% retornam 200).

## 4. A hora do pico
```bash
awk '{split($4,a,":"); print a[2]}' dados/access.log | sort | uniq -c | sort -k2,2n
```
```
00 3262  01 1967  02 1810  03 1471  04 1498  05 1844
06 3904  07 9759  08 19519  09 27621  10 30869  11 32526
12 31895  13 29952  14 31225  15 32529  16 30886  17 28575
18 25996  19 22807  20 18860  21 15577  22 43979  23 68535
```
**Leitura:** O pico foi às 23h (68.535 requisições), seguido das 22h (43.979), coincidindo com a concentração do IP automatizado.

## 5. Alguém batendo na porta
```bash
awk 'BEGIN{IGNORECASE=1} $7 ~ /(^|\/)(admin([\/?]|$)|phpmyadmin([\/?]|$)|wp-login([^\/]*)([\/?]|$)|\.env([\/?]|$)|\.git([\/?]|$))/ {hits++; ip[$1]=1; status[$9]++} END{for(i in ip)n++; printf "tentativas=%d ips_distintos=%d\n",hits,n; for(s in status) print s,status[s]}' dados/access.log
```
```
tentativas=2080 ips_distintos=2
404 2080
```
```bash
awk 'BEGIN{IGNORECASE=1} $7 ~ /(^|\/)(admin([\/?]|$)|phpmyadmin([\/?]|$)|wp-login([^\/]*)([\/?]|$)|\.env([\/?]|$)|\.git([\/?]|$))/ {print $7}' dados/access.log | sort | uniq -c | sort -nr
```
```
382 /admin/login   368 /wp-login.php   356 /.git/config
343 /.env          318 /phpmyadmin/index.php   313 /admin
```
**Leitura:** Foram 2.080 sondagens, de 2 IPs distintos; todas receberam 404. A variedade dos caminhos caracteriza reconhecimento automatizado.

## Conclusao: minha primeira acao como operador de plantao
Bloquear emporariamente `203.0.113.47` no irewall e abriria alerta para investigar `/api/relatorio/gerar`. O IP gerou 88.400 requisições automatizadas em duas horas e 6.900 respostas 503; conter a origem reduz a pressão enquanto se investiga a falha intermitente de 34,81%.
