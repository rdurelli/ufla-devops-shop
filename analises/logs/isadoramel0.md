## 1. Volume e falha

```bash
awk '$9 ~ /^4/' dados/access.log | wc -l
awk '$9 ~ /^5/' dados/access.log | wc -l

6162
11749
```

**Leitura:** Das 516.866 requisições totais, 6.162 (1,19%) falharam com erro de cliente (4xx) e 11.749 (2,27%) falharam com erro de servidor (5xx) — quase o dobro dos erros de cliente, o que indica que o problema está mais no lado do servidor do que em requisições malformadas.

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

**Leitura:** O IP `203.0.113.47` é claramente suspeito: 88.400 requisições, quase 50x mais que o segundo colocado. Por isso, foi feita uma investigação mais detalhada desse IP.

### Investigando o IP suspeito

Primeiro, verificamos quais endpoints foram acessados:

```bash
grep '^203.0.113.47' dados/access.log | awk '{print $7}' | sort | uniq -c | sort -rn | head -10
```

Resultado:

```text
 22224 /api/busca?q=mochila
 22161 /api/busca?q=tenis
 22090 /api/busca?q=camiseta
 21925 /api/busca?q=fone
```

Isso mostra que o IP concentrou suas requisições exclusivamente no endpoint `/api/busca`, utilizando apenas quatro termos de busca.

Em seguida, verificamos em quais horários essas requisições ocorreram:

```bash
grep '^203.0.113.47' dados/access.log | awk -F'[' '{print $2}' | cut -d: -f2 | sort | uniq -c
```

Resultado:

```text
 30940 22
 57460 23
```

As 88.400 requisições ocorreram exclusivamente entre 22h e 23h, com maior concentração às 23h.

Por fim, verificamos o user-agent utilizado:

```bash
grep '^203.0.113.47' dados/access.log | awk -F'"' '{print $6}' | sort | uniq -c | sort -rn
```

Resultado:

```text
 88400 curl/8.5.0
```

Ou seja, 100% das requisições utilizaram o user-agent `curl/8.5.0`.

 O padrão observado é fortemente indicativo de scraping automatizado: um único IP realizou 88.400 requisições, todas direcionadas ao mesmo endpoint, utilizando apenas quatro termos fixos de busca, concentradas em duas horas e com o user-agent `curl/8.5.0` em 100% dos casos. Esse comportamento é incompatível com o padrão esperado de um usuário humano e caracteriza tráfego automatizado.

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

```bash
awk '$7 == "/api/relatorio/gerar"' dados/access.log | wc -l
```

```text
10400
```

**Leitura:** O endpoint `/api/relatorio/gerar` concentra a esmagadora maioria dos erros 500 (3.620, mais de 15x o segundo colocado). Comparando com o total de chamadas a esse caminho (10.400), a taxa de falha é de 34,8% ou seja, ele quebra em cerca de 1 a cada 3 requisições. Não é uma falha constante, mas é frequente o suficiente para sugerir um problema estrutural (provavelmente timeout ou esgotamento de recurso ao gerar o relatório) em vez de um bug raro.

## 4. A hora do pico

```bash
awk -F'[' '{print $2}' dados/access.log | cut -d: -f2 | sort | uniq -c | sort -rn
```

```text
68535 23
43979 22
32529 15
32526 11
31895 12
31225 14
30886 16
30869 10
29952 13
28575 17
27621 09
25996 18
22807 19
19519 08
18860 20
15577 21
9759 07
3904 06
3262 00
1967 01
1844 05
1810 02
1498 04
1471 03
```

**Leitura:** O pico absoluto foi às 23h (68.535 requisições), seguido de 22h (43.979) — mas esse pico está inflado pelo IP suspeito identificado na Pergunta 2, que concentrou seu scraping justamente nessas duas horas. Descontando esse ruído, o tráfego se distribui de forma relativamente uniforme durante o horário comercial (9h às 19h, entre 22 e 33 mil requisições por hora), com queda acentuada durante a madrugada (0h às 6h, abaixo de 4 mil).

## 5. Alguém batendo na porta

```bash
grep -E '/admin|\.env|\.git|wp-login|phpmyadmin' dados/access.log | wc -l
grep -E '/admin|\.env|\.git|wp-login|phpmyadmin' dados/access.log | awk '{print $1}' | sort -u | wc -l
grep -E '/admin|\.env|\.git|wp-login|phpmyadmin' dados/access.log | awk '{print $9}' | sort | uniq -c | sort -rn
grep -E '/admin|\.env|\.git|wp-login|phpmyadmin' dados/access.log | awk '{print $1}' | sort -u
```

```text
2080
2
2080 404
198.51.100.23
198.51.100.9
```

**Leitura:** Houve 2.080 tentativas de acesso a caminhos sensíveis (/admin, .env, .git, wp-login, phpmyadmin), partindo de apenas 2 IPs distintos (198.51.100.23 e 198.51.100.9) — um padrão típico de varredura automatizada de vulnerabilidades, não de tráfego legítimo. O servidor respondeu 404 em 100% das tentativas: nenhum desses caminhos existe de fato na aplicação, então não houve exposição real de dados.

## Conclusão: minha primeira ação como operador de plantão

Como operadora de plantão, minha primeira ação seria **bloquear o IP 203.0.113.47** no nível do proxy/firewall. Ele sozinho respondeu por 88.400 das 516.866 requisições (~17% do tráfego total da madrugada), martelando o endpoint `/api/busca` com um padrão inequívoco de scraping automatizado (user-agent `curl`, poucos termos fixos, volume concentrado em 2 horas). Esse consumo desproporcional de recursos é o candidato mais provável a estar contribuindo para a instabilidade do `/api/relatorio/gerar`, que já falha em 34,8% das chamadas bloquear o scraper primeiro é a ação mais rápida e reversível, e me dá espaço para investigar com calma, em seguida, a causa raiz do erro 500 nesse endpoint (provável timeout ou esgotamento de recurso).
