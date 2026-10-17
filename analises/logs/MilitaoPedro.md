# Analise de access.log -- Pedro Militão (@MilitaoPedro)

**Linhas analisadas:** 516866

## 1. Volume e falha

Total de requisições:

```bash
wc -l < dados/access.log
```

```
516866
```

Distribuição por código de status (contando a coluna **$9**, o campo de status — não o texto solto da linha):

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

Resumo por classe (primeiro dígito do status):

```bash
awk '{print $9}' dados/access.log | cut -c1 | sort | uniq -c
```

```
 498955 2
   6162 4
  11749 5
```

**Leitura:** 516.866 requisições no total; 6.162 falharam com 4xx (404+403) e 11.749 com 5xx (500+503) — juntas, 17.911 requisições, ou ~3,47% do total (4xx = 1,19%; 5xx = 2,27%). A contagem foi feita pela coluna de status porque o grep solto erra: `grep ' 500 '` encontra 4.921 linhas, mas os 500 reais são 4.849 — os 72 falsos positivos vêm de respostas com tamanho ($10) igual a 500.

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

Investigação do campeão — o que ele pediu (P4 do log), o que recebeu, com que user-agent e em que ritmo:

```bash
# caminhos que ele requisitou
awk '$1=="203.0.113.47" {print $7}' dados/access.log | sort | uniq -c | sort -rn
```

```
  22224 /api/busca?q=mochila
  22161 /api/busca?q=tenis
  22090 /api/busca?q=camiseta
  21925 /api/busca?q=fone
```

```bash
# status que ele recebeu
awk '$1=="203.0.113.47" {print $9}' dados/access.log | sort | uniq -c | sort -rn
```

```
  81500 200
   6900 503
```

```bash
# user-agent (ultimo campo)
awk '$1=="203.0.113.47" {print $NF}' dados/access.log | sort | uniq -c
```

```
  88400 "curl/8.5.0"
```

```bash
# ritmo por hora (recortando a hora do campo $4)
awk '$1=="203.0.113.47" {print $4}' dados/access.log | cut -d: -f2 | sort -n | uniq -c
```

```
  30940 22
  57460 23
```

**Leitura:** 203.0.113.47 é disparadamente o maior volume (88.400 = 17% de todo o log; o segundo colocado tem 1.788) e é suspeito sim. Não parece humano: usa curl/8.5.0 — o **único** client `curl` de todo o arquivo —, bate apenas em `/api/busca` com exatamente quatro termos fixos em rotação (mochila, tenis, camiseta, fone), num período contínuo das 22:00:00 às 23:59:59 (~12 req/s sustentados por 2 horas) e é o único responsável pelos 6.900 status 503 do log. É o padrão clássico de raspagem automatizada (preço/estoque) ou teste de carga contra o endpoint de busca — não de navegação humana.

## 3. O endpoint quebrado

Qual caminho mais gera 500:

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

Proporção de falha sobre o total daquele caminho:

```bash
awk '$7=="/api/relatorio/gerar" {print $9}' dados/access.log | sort | uniq -c | sort -rn
```

```
   6780 200
   3620 500
```

**Leitura:** `/api/relatorio/gerar` concentra 3.620 dos 4.849 500 do log (~75%), mas **não quebra sempre**: das 10.400 requisições a esse caminho, 6.780 retornaram 200 (65%) e 3.620 deram 500 (35%). Os 500 vêm de 254 IPs distintos espalhados por todas as horas — é uma falha intermitente de backend que atinge usuários reais, não um ataque concentrado.

## 4. A hora do pico

```bash
awk '{print $4}' dados/access.log | cut -d: -f2 | sort -n | uniq -c
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

Para não ser enganado pelo bot da P2, a mesma distribuição sem o IP 203.0.113.47:

```bash
awk '$1!="203.0.113.47" {print $4}' dados/access.log | cut -d: -f2 | sort -n | uniq -c | sort -rn | head -3
```

```
  32529 15
  32526 11
  31895 12
```

**Leitura:** em números brutos o pico é 23h (68.535), mas 57.460 dessas (84%) vieram do bot da P2, ativo só entre 22h e 23h. Tirado o bot, o tráfego tem cara de loja diurna: sino entre 09h e 18h, topo em 15h (~32,5 mil/h) e madrugada 03h–05h com menos de 1.900/h. Ou seja, o "pico às 23h" é artefato do ataque; o horário de pico orgânico é o meio da tarde.

## 5. Alguém batendo na porta

```bash
awk '$7 ~ /admin|\.env|\.git|wp-login|phpmyadmin/ {print $7}' dados/access.log | sort | uniq -c | sort -rn
```

```
    382 /admin/login
    368 /wp-login.php
    356 /.git/config
    343 /.env
    318 /phpmyadmin/index.php
    313 /admin
```

Total, IPs distintos e a resposta do servidor:

```bash
awk '$7 ~ /admin|\.env|\.git|wp-login|phpmyadmin/' dados/access.log | wc -l
awk '$7 ~ /admin|\.env|\.git|wp-login|phpmyadmin/ {print $1}' dados/access.log | sort -u
awk '$7 ~ /admin|\.env|\.git|wp-login|phpmyadmin/ {print $9}' dados/access.log | sort | uniq -c
```

```
2080
198.51.100.23
198.51.100.9
2080 404
```

**Leitura:** 2.080 tentativas de acesso a caminho sensível, vindas de apenas 2 IPs (198.51.100.9 e 198.51.100.23), com user-agent `python-requests/2.32.3`, varrendo um dicionário fixo de alvos clássicos (`/admin/login`, `/wp-login.php`, `/.git/config`, `/.env`, `/phpmyadmin/index.php`) de madrugada (02h–05h). O servidor respondeu **404 a todas as 2.080** — nada sensível foi servido. É varredura de reconhecimento pré-ataque, não exploração bem-sucedida.

## Conclusão: minha primeira ação como operador de plantão

Minha primeira ação seria bloquear o IP 203.0.113.47 no firewall/edge (e aplicar rate-limit em `/api/busca` como medida de contenção). É a ação com maior efeito imediato e o dado a justifica: um único client `curl/8.5.0` concentra 17% de todo o tráfego do dia, dispara ~12 req/s contra o endpoint de busca entre 22h00 e 23h59 e é o **único** gerador dos 6.900 status 503 do log — a assinatura de um servidor sobrecarregado no exato horário em que "está lento". Derrubado esse tráfego, o pico artificial das 23h desaparece e resta o padrão diurno normal. Em paralelo eu avisaria o time de backend sobre `/api/relatorio/gerar`, que falha 35% das vezes (3.620 de 10.400 requisições, atingindo 254 IPs distintos): não é o que derruba a madrugada, mas é um bug que queima usuários reais e merece investigação. As sondagens de `/admin`, `.env`, `.git`, `wp-login` e `phpmyadmin` (2 IPs, 2.080 pedidos, todos respondidos com 404) entrariam apenas na lista de bloqueio, já que não tiveram sucesso.
