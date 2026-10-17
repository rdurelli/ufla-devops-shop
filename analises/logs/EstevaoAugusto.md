# Analise de access.log -- Estevão Augusto da Fonseca Santos (@EstevaoAugusto)

**Linhas analisadas:** 516866

## 1. Volume e falha: Quantas requisições o log tem no total? Quantas falharam com 4xx e quantas com 5xx? Que percentual do total isso representa?

```bash
wc -l access.log
```

```
516866 access.log
``` 


```bash
awk '$9 >= 400 && $9 <= 499' access.log | wc -l
```

```
6162
``` 

```bash
awk '$9 >= 500 && $9 <= 599' access.log | wc -l
```

```
11749
``` 

**Leitura:** Somando os erros 4xx e 5xx, o log apresenta um total de 17.911 falhas, o que corresponde a aproximadamente 3,47% de taxa de erro global. O serviço respondeu com sucesso (ou redirecionamento) para 96,53% do tráfego. O número de erros do lado do servidor (5xx: 11.749) é quase o dobro dos erros do lado do cliente (4xx: 6.162) indicando que a aplicação está sofrendo mais com falhas internas (ex: timeouts, exceções não tratadas em endpoints, concorrência no banco de dados) do que com clientes tentando acessar URLs inexistentes (404) ou sem permissão (403).

## 2. Quem bateu mais. Quais são os 10 IPs mais frequentes, com a contagem de cada um? Algum deles é suspeito? Justifique — e não vale “é o que aparece mais”. Olhe o que esse IP estava pedindo, em que ritmo, e com que user-agent.

```bash
awk '{print $1}' access.log | sort | uniq -c | sort -nr | head -n 10
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

Vamos focar no IP 203.0.113.47

```bash
grep '^203\.0\.113\.47' access.log | awk '{print $6, $7}' | sort | uniq -c | sort -nr | head -n 10
```


```
22224 "GET /api/busca?q=mochila
22161 "GET /api/busca?q=tenis
22090 "GET /api/busca?q=camiseta
21925 "GET /api/busca?q=fone
```

```bash
grep '^203\.0\.113\.47' access.log | awk -F'"' '{print $6}' | sort | uniq -c
```

```
88400 curl/8.5.0
```

```bash
grep '^203\.0\.113\.47' access.log | awk '{print $4}' | cut -d: -f1,2,3 | uniq -c | head -n 20
```

```
1 [14/Aug/2026:22:24
1 [14/Aug/2026:22:13
1 [14/Aug/2026:22:32
1 [14/Aug/2026:22:18
1 [14/Aug/2026:22:45
1 [14/Aug/2026:22:16
1 [14/Aug/2026:22:01
1 [14/Aug/2026:22:42
1 [14/Aug/2026:22:26
1 [14/Aug/2026:22:17
1 [14/Aug/2026:22:44
1 [14/Aug/2026:22:03
1 [14/Aug/2026:22:22
1 [14/Aug/2026:22:32
1 [14/Aug/2026:22:59
1 [14/Aug/2026:22:28
1 [14/Aug/2026:22:25
1 [14/Aug/2026:22:04
1 [14/Aug/2026:22:14
1 [14/Aug/2026:22:05
```

Vamos focar no IP 192.0.2.XXX

```bash
grep '^192\.0\.2\.' access.log | awk '{print $6, $7}' | sort | uniq -c | sort -nr | head -n 10

```

```
71682 "GET /
58793 "GET /produtos
52100 "GET /api/produtos
45541 "GET /produtos/detalhe
39266 "GET /static/app.css
39197 "GET /static/app.js
29395 "GET /api/carrinho
22851 "GET /api/busca
19534 "GET /favicon.ico
14721 "GET /api/pedidos
```

```bash
grep '^192\.0\.2\.' access.log | awk -F'"' '{print $6}' | sort | uniq -c
```

```
107046 Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) AppleWebKit/605.1.15 Mobile/15E148
106858 Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4 Safari/605.1.15
106592 Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0 Safari/537.36
105890 Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/127.0 Safari/537.36
```

```bash
grep '^192\.0\.2\.' access.log | awk '{print $4}' | cut -d: -f1,2,3 | uniq -c | head -n 20
```

```
1 [14/Aug/2026:00:36
1 [14/Aug/2026:00:01
1 [14/Aug/2026:00:02
1 [14/Aug/2026:00:25
1 [14/Aug/2026:00:05
1 [14/Aug/2026:00:39
1 [14/Aug/2026:00:12
1 [14/Aug/2026:00:41
1 [14/Aug/2026:00:57
1 [14/Aug/2026:00:09
1 [14/Aug/2026:00:36
1 [14/Aug/2026:00:56
1 [14/Aug/2026:00:57
1 [14/Aug/2026:00:31
1 [14/Aug/2026:00:43
1 [14/Aug/2026:00:00
1 [14/Aug/2026:00:33
1 [14/Aug/2026:00:59
1 [14/Aug/2026:00:46
1 [14/Aug/2026:00:37
```

**Leitura:** O IP 203.0.113.47 é altamente suspeito de ser um script/bot automatizado de raspagem ou teste de estresse, pois gerou sozinho 88.400 requisições (~17% de todo o tráfego do servidor) utilizando exclusivamente o User-Agent curl/8.5.0. Sua maliciosidade se confirma pelo comportamento repetitivo de bombardear o endpoint /api/busca alternando entre apenas 4 termos (mochila, tenis, camiseta e fone), em contraste claro com a faixa 192.0.2.XXX, que reflete o comportamento legítimo de usuários reais carregando ativos estáticos (CSS/JS) e navegadores diversos.

## 3. O endpoint quebrado. Qual caminho causou mais erro 500? Ele quebra sempre ou só às vezes? (Compare o total de requisições daquele caminho com o total de 500 dele.)

```bash
awk '
awk '$9 >= 500 && $9 <= 599 { split($7, a, "?"); print a[1] }' access.log | sort | uniq -c | sort -nr | head -n 5
```

```bash
6963 /api/busca
3620 /api/relatorio/gerar
228 /
167 /api/produtos
160 /produtos
```

```bash
awk '
awk -v path="/api/busca" '{ split($7, a, "?"); if (a[1] == path) print $9 }' access.log | sort | uniq -c
```

```bash
104034 200
101 403
153 404
63 500
6900 503
```

**Leitura:** O caminho que mais gerou erros de servidor foi o /api/busca (com 6.963 falhas na família 5xx, sendo 63 erros HTTP 500 e 6.900 HTTP 503). Ele quebra só às vezes (falha intermitente, provavelmente associada à sobrecarga do bot visto na Questão 2), já que das 111.251 requisições totais feitas a ele, a grande maioria (104.034 ou ~93,5%) respondeu com sucesso (HTTP 200), enquanto apenas ~6,3% resultaram em falha do servidor.

## 4. A hora do pico. Em qual hora do dia houve mais tráfego? Mostre a distribuição por hora, não só o vencedor.

```bash
awk '{ split($4, a, ":"); print a[2]"h" }' access.log | sort | uniq -c | sort -k2 -n
```

```
3262 00h
1967 01h
1810 02h
1471 03h
1498 04h
1844 05h
3904 06h
9759 07h
19519 08h
27621 09h
30869 10h
32526 11h
31895 12h
29952 13h
31225 14h
32529 15h
30886 16h
28575 17h
25996 18h
22807 19h
18860 20h
15577 21h
43979 22h
68535 23h
```

**Leitura:** O pico absoluto de tráfego ocorreu às 23h com 68.535 requisições (seguido pelas 22h com 43.979), concentrando o volume gerado em grande parte pelas automações noturnas. Ao longo do dia, o tráfego de usuários reais cresce rapidamente a partir das 07h, sustentando um patamar elevado e estável em torno de 30k a 32k requisições/hora entre 10h e 16h, e atingindo o menor volume de tráfego às 03h (1.471 requisições).

## 5. Há tentativa de acesso a caminho sensível — /admin, .env, .git, wp-login, /phpmyadmin? Quantas, de quantos IPs distintos, e o que o servidor respondeu a elas?

```bash
grep -E '(/admin|\.env|\.git|wp-login|phpmyadmin)' access.log | wc -l
```

```bash
2080
```

```bash
grep -E '(/admin|\.env|\.git|wp-login|phpmyadmin)' access.log | awk '{print $1}' | sort -u | wc -l
```

```bash
2
```

```bash
grep -E '(/admin|\.env|\.git|wp-login|phpmyadmin)' access.log | awk '{print $9}' | sort | uniq -c
```

```bash
2080 404
```

**Leitura:** Sim, foram registradas 2.080 tentativas de acesso a caminhos sensíveis originadas de apenas 2 IPs distintos, caracterizando uma varredura automatizada (fuzzing/reconhecimento) de vulnerabilidades. O servidor respondeu com HTTP 404 (Not Found) a 100% das requisições, confirmando que nenhum arquivo ou painel sensível foi exposto ou comprometido.

## Conclusao: minha primeira acao como operador de plantao

Como primeira ação de mitigação imediata, o operador de plantão deve aplicar o bloqueio sumário do IP **203.0.113.47** no WAF ou firewall da aplicação, estancando as 88.400 requisições automatizadas via `curl` que sobrecarregam o endpoint `/api/busca` e geram 6.900 erros HTTP 503 (Service Unavailable); essa contenção emergencial corta de imediato cerca de 60% de todas as falhas 5xx do servidor, restabelecendo a estabilidade da aplicação para o tráfego legítimo dos usuários e abrindo margem técnica para a aplicação subsequente de *rate limiting* na rota afetada.
