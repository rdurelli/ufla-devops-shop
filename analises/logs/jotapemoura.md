# Analise de access.log -- João Pedro Dos Reis Moura(jotapemoura)
**Linhas analisadas:** <saida do wc -l>
## 1. Volume e falha
wc -l dados/access.log
saída: 516866 dados/access.log

awk '$9 ~ /^4/' dados/access.log | wc -l
saída: 6162

awk '$9 ~ /^5/' dados/access.log | wc -l
saída: 11749

awk '{print $9}' dados/access.log | grep -E '^[45]' | cut -c1 | sort | uniq -c
saída: 
 6162 4
  11749 5

**Leitura:** Com o total de 516.866 requisições, os erros 4xx correspondem a 1,19% e os erros 5xx representam 2,27% do tráfego total.
## 2. Os 10 IPs mais frequentes
awk '{print $1}' dados/access.log | sort | uniq -c | sort -rn | head -10
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

grep 203.0.113.47 dados/access.log | head -20

203.0.113.47 - - [14/Aug/2026:22:24:51 +0000] "GET /api/busca?q=tenis HTTP/1.1" 200 1279 "-" "curl/8.5.0"
203.0.113.47 - - [14/Aug/2026:22:13:01 +0000] "GET /api/busca?q=tenis HTTP/1.1" 503 203 "-" "curl/8.5.0"
203.0.113.47 - - [14/Aug/2026:22:32:10 +0000] "GET /api/busca?q=camiseta HTTP/1.1" 200 797 "-" "curl/8.5.0"
203.0.113.47 - - [14/Aug/2026:22:18:30 +0000] "GET /api/busca?q=fone HTTP/1.1" 200 1332 "-" "curl/8.5.0"
203.0.113.47 - - [14/Aug/2026:22:45:53 +0000] "GET /api/busca?q=fone HTTP/1.1" 503 155 "-" "curl/8.5.0"
203.0.113.47 - - [14/Aug/2026:22:16:52 +0000] "GET /api/busca?q=mochila HTTP/1.1" 200 1623 "-" "curl/8.5.0"
203.0.113.47 - - [14/Aug/2026:22:01:55 +0000] "GET /api/busca?q=mochila HTTP/1.1" 200 925 "-" "curl/8.5.0"
203.0.113.47 - - [14/Aug/2026:22:42:35 +0000] "GET /api/busca?q=fone HTTP/1.1" 200 455 "-" "curl/8.5.0"
203.0.113.47 - - [14/Aug/2026:22:26:28 +0000] "GET /api/busca?q=fone HTTP/1.1" 200 1619 "-" "curl/8.5.0"
203.0.113.47 - - [14/Aug/2026:22:17:06 +0000] "GET /api/busca?q=mochila HTTP/1.1" 200 472 "-" "curl/8.5.0"
203.0.113.47 - - [14/Aug/2026:22:44:06 +0000] "GET /api/busca?q=mochila HTTP/1.1" 200 1676 "-" "curl/8.5.0"
203.0.113.47 - - [14/Aug/2026:22:03:31 +0000] "GET /api/busca?q=tenis HTTP/1.1" 200 1120 "-" "curl/8.5.0"
203.0.113.47 - - [14/Aug/2026:22:22:38 +0000] "GET /api/busca?q=tenis HTTP/1.1" 200 1129 "-" "curl/8.5.0"
203.0.113.47 - - [14/Aug/2026:22:32:51 +0000] "GET /api/busca?q=tenis HTTP/1.1" 200 694 "-" "curl/8.5.0"
203.0.113.47 - - [14/Aug/2026:22:59:36 +0000] "GET /api/busca?q=camiseta HTTP/1.1" 200 1699 "-" "curl/8.5.0"
203.0.113.47 - - [14/Aug/2026:22:28:42 +0000] "GET /api/busca?q=mochila HTTP/1.1" 200 1142 "-" "curl/8.5.0"
203.0.113.47 - - [14/Aug/2026:22:25:44 +0000] "GET /api/busca?q=mochila HTTP/1.1" 200 1106 "-" "curl/8.5.0"
203.0.113.47 - - [14/Aug/2026:22:04:39 +0000] "GET /api/busca?q=fone HTTP/1.1" 200 1606 "-" "curl/8.5.0"
203.0.113.47 - - [14/Aug/2026:22:14:43 +0000] "GET /api/busca?q=tenis HTTP/1.1" 200 573 "-" "curl/8.5.0"
203.0.113.47 - - [14/Aug/2026:22:05:53 +0000] "GET /api/busca?q=fone HTTP/1.1" 200 1351 "-" "curl/8.5.0"

Leitura: O IP 203.0.113.47 é suspeito porque realiza requisições automatizadas via curl/8.5.0 diretamente na API de busca (/api/busca), simulando um bot de raspagem de dados (scraping). O ritmo intenso de requisições gerou inclusive respostas com código HTTP 503, demonstrando que a automação provocou instabilidade/sobrecarga momentânea no serviço.
...mesma estrutura para as perguntas 2 a 5...
3

Pergunta 3 O endpoint quebrado: awk '$9 == 500 {print $7}' dados/access.log | sort | uniq -c | sort -rn | head -1
Saída:    3620 /api/relatorio/gerar
awk '$7 == "/api/relatorio/gerar"' dados/access.log | wc -l
saída: 10400
Leitura: O caminho /api/relatorio/gerar foi a rota que mais gerou falhas internas (3.620 erros 500). Das 10.400 requisições direcionadas a esse endpoint, 34,81% resultaram em erro 500, o que confirma um comportamento de falha intermitente (não quebra em 100% dos acessos).

Pergunta 4: Horário de Pico
awk '{print $4}' dados/access.log | cut -d: -f2 | sort | uniq -c | sort -n
saída: 1471 03
   1498 04
   1810 02
   1844 05
   1967 01
   3262 00
   3904 06
   9759 07
  15577 21
  18860 20
  19519 08
  22807 19
  25996 18
  27621 09
  28575 17
  29952 13
  30869 10
  30886 16
  31225 14
  31895 12
  32526 11
  32529 15
  43979 22
  68535 23
Leitura: o horário de pico foi às 23 horas com 68535 requisições.

Pergunta 5: Algúem batendo na porta

awk '$7 ~ /(\/admin|\.env|\.git|wp-login|\/phpmyadmin)/' dados/access.log | wc -l
saída: 2080

Quantidade de IPs distintos realizando as tentativas:
awk '$7 ~ /(\/admin|\.env|\.git|wp-login|\/phpmyadmin)/ {print $1}' dados/access.log | sort -u | wc -l
saida: 2

Respostas do servidor (Status HTTP) para essas tentativas:

awk '$7 ~ /(\/admin|\.env|\.git|wp-login|\/phpmyadmin)/ {print $9}' dados/access.log | sort | uniq -c | sort -rn
saida: 2080 404
Leitura: Foram registradas 2.080 tentativas de acesso a caminhos sensíveis por 2 IPs distintos. Foram respondidos pelo código 404, demonstrando segurança.
Atividade 2 DevOps na Prática — 10A-14A — 2026/2
## Conclusao: minha primeira acao como operador de plantao
<um paragrafo, com uma acao concreta justificada pelos dados>
    
    Como primeira ação imediata no horário de pico (23h, com 68.535 requisições), eu aplicaria um bloqueio no firewall/WAF para o IP 203.0.113.47 e desativaria temporariamente o endpoint /api/relatorio/gerar. Essa medida justifica-se porque o IP em questão está executando um scraping automatizado via curl que sobrecarrega a API de busca, e o endpoint de relatórios é responsável por sozinho 3.620 dos 11.749 erros 5xx registrados (30,8% do total de falhas do servidor), consumindo recursos computacionais críticos no momento de maior volume de tráfego do sistema.
