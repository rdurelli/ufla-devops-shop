# Analise de access.log -- Felipe Geraldo de Oliveira (@FelipeOliveira456)

**Linhas analisadas:** 516866

## 1. Volume e falha

```bash
awk '{
  total++
  if ($9 ~ /^4/) c4++
  if ($9 ~ /^5/) c5++
}
END {
  printf "total=%d\n4xx=%d (%.2f%%)\n5xx=%d (%.2f%%)\n", total, c4, 100*c4/total, c5, 100*c5/total
}' dados/access.log
```

```
total=516866
4xx=6162 (1.19%)
5xx=11749 (2.27%)
```

**Leitura:** Sao 516866 requisicoes. A fatia que dói e o 5xx (2,27%), nao o 4xx (1,19%). Contei pelo campo `$9` (status HTTP), nao com `grep 500`, para nao confundir codigo de erro com tamanho da resposta.

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

Investigacao do primeiro colocado:

```bash
awk '$1=="203.0.113.47" {
  n++; path[$7]++; ua[$NF]++; st[$9]++; split($4,a,":"); hora[a[2]]++
}
END {
  print "total", n
  for (u in ua) print "ua", u, ua[u]
  for (p in path) print "path", p, path[p]
  for (s in st) print "status", s, st[s]
  for (h in hora) print "hora", h, hora[h]
}' dados/access.log
```

```
total 88400
ua "curl/8.5.0" 88400
path /api/busca?q=mochila 22224
path /api/busca?q=fone 21925
path /api/busca?q=tenis 22161
path /api/busca?q=camiseta 22090
status 200 81500
status 503 6900
hora 23 57460
hora 22 30940
```

Ritmo (requisicoes por minuto, so os picos):

```bash
awk '$1=="203.0.113.47" {split($4,a,":"); print a[2]":"a[3]}' dados/access.log | sort | uniq -c | sort -rn | head -5
```

```
   1021 23:44
   1017 23:00
   1015 23:32
   1007 23:21
   1002 23:17
```

**Leitura:** `203.0.113.47` sozinho e ~17% do log (88400/516866). Nao e o visitante mais popular: e um cliente em laco. So pede `/api/busca` com quatro queries, user-agent `curl/8.5.0`, concentra 22h-23h e chega a ~1000 req/min. Ainda gera 6900 respostas 503 — o servidor ja estava recusando parte do volume. Os outros nove IPs ficam na casa de 1,7 mil e parecem trafego normal.

## 3. O endpoint quebrado

```bash
awk '$9==500 {print $7}' dados/access.log | sort | uniq -c | sort -rn | head -5
```

```
   3620 /api/relatorio/gerar
    228 /
    167 /api/produtos
    160 /produtos
    150 /produtos/detalhe
```

```bash
awk '$7=="/api/relatorio/gerar" {t++; if ($9==500) e++}
END {printf "total=%d 500=%d taxa=%.2f%%\n", t, e, 100*e/t}' dados/access.log
```

```
total=10400 500=3620 taxa=34.81%
```

**Leitura:** `/api/relatorio/gerar` lidera os 500 e nao quebra sempre: 3620 de 10400 chamadas (34,81%). Os outros caminhos mal passam de 1% de 500. E bug intermitente nesse endpoint, nao uma queda geral da API.

## 4. A hora do pico

```bash
awk '{split($4, a, ":"); print a[2]}' dados/access.log | sort | uniq -c | sort -k2,2n
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

**Leitura:** Madrugada baixa, manha/tarde altas — perfil de loja. O pico absoluto e **23h** (68535); 22h ja esta inflada (43979). Isso casa com o laco do `203.0.113.47`, que so aparece nessas duas horas. Sem esse IP, 23h nao seria o topo.

## 5. Alguem batendo na porta

```bash
awk '
$7 ~ /\/admin|\/\.env|\/\.git|wp-login|phpmyadmin/ {
  n++
  ip[$1]
  st[$9]++
  path[$7]++
}
END {
  print "requisicoes=" n
  print "ips_distintos=" length(ip)
  for (i in ip) print "ip=" i
  for (s in st) print "status", s "=" st[s]
  for (p in path) print "caminho", p "=" path[p]
}' dados/access.log
```

```
requisicoes=2080
ips_distintos=2
ip=198.51.100.9
ip=198.51.100.23
status 404=2080
caminho /wp-login.php=368
caminho /phpmyadmin/index.php=318
caminho /.git/config=356
caminho /admin/login=382
caminho /admin=313
caminho /.env=343
```

**Leitura:** 2080 tentativas, 2 IPs distintos (`198.51.100.9` e `198.51.100.23`). Caminhos: `/admin`, `/admin/login`, `/.env`, `/.git/config`, `/wp-login.php`, `/phpmyadmin/index.php`. O servidor respondeu **404 em 100%** — nao vazou nada. E varredura, nao incidente aberto; ainda assim fica no radar.

## Conclusao: minha primeira acao como operador de plantao

Bloquear (ou rate-limitar de imediato) o IP `203.0.113.47` no Nginx/firewall. Ele e ~17% do trafego, ~1000 req/min so em `/api/busca`, user-agent `curl`, e ja provoca 503. Isso explica o pico das 23h e e reversivel num comando. Em seguida eu abriria chamado para o time de aplicacao sobre `/api/relatorio/gerar` (35% de 500): isso e bug, nao se resolve no plantao com firewall. Os scans em `/admin` e `.env` eu so monitoraria — ja estao todos em 404.
