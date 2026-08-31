# Analise de access.log -- Dominic Laercio Braz Dias (@DominicLaercio)

**Linhas analisadas:** 516866

## 1. Volume e falha

```bash
wc -l dados/access.log
awk '$9 ~ /^4/ {count++} END {print count}' dados/access.log
awk '$9 ~ /^5/ {count++} END {print count}' dados/access.log

```

```
516866 dados/access.log
6162
11749

```

**Leitura:** O arquivo possui 516.866 requisições no total. Foram registrados 6.162 erros do tipo 4xx (1,19%) e 11.749 erros do tipo 5xx (2,27%), totalizando 17.911 falhas (aproximadamente 3,46% do tráfego total do servidor).

## 2. Os 10 IPs mais frequentes

```bash
awk '{print $1}' dados/access.log | sort | uniq -c | sort -rn | head -10
awk -v ip=203.0.113.47 '$1 == ip {print $7}' dados/access.log | sort | uniq -c | sort -rn | head -10
awk -v ip=203.0.113.47 '$1 == ip {print $12}' dados/access.log | sort | uniq -c

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

# Investigacao do IP 203.0.113.47:
22224 /api/busca?q=mochila
22161 /api/busca?q=tenis
22090 /api/busca?q=camiseta
21925 /api/busca?q=fone

88400 "curl/8.5.0"

```

**Leitura:** O IP `203.0.113.47` é extremamente suspeito, sendo responsável por sozinho 88.400 requisições (cerca de 17,1% de todo o tráfego do servidor). A investigação mostrou que 100% das suas chamadas foram feitas via `curl/8.5.0` (script de automação) fazendo varreduras intensivas no endpoint `/api/busca`, caracterizando um scraping agressivo ou ataque de negação de serviço (DoS).

## 3. O endpoint quebrado

```bash
awk '$9 ~ /^5/ {print $7}' dados/access.log | sort | uniq -c | sort -rn | head -5
awk -v path=/api/relatorio/gerar '$7 == path' dados/access.log | wc -l
awk -v path=/api/relatorio/gerar '$7 == path && $9 == "500"' dados/access.log | wc -l

```

```
3620 /api/relatorio/gerar
1757 /api/busca?q=camiseta
1752 /api/busca?q=tenis
1752 /api/busca?q=mochila
1639 /api/busca?q=fone

10400
3620

```

**Leitura:** O caminho `/api/relatorio/gerar` foi o isolado que mais causou erro 500 no servidor, com 3.620 ocorrências. Ele não quebra sempre, mas sim de forma intermitente: das 10.400 vezes em que foi requisitado, apresentou falha em aproximadamente 34,8% das chamadas, o que sugere um problema de timeout ou falta de recursos sob alta carga ao processar relatórios pesados.

## 4. A hora do pico

```bash
awk '{print $4}' dados/access.log | cut -d: -f2 | sort | uniq -c | sort -rn

```

```
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

**Leitura:** O horário de maior pico de tráfego ocorreu às 23h, registrando 68.535 requisições. O volume de acessos cresce significativamente a partir das 22h e atinge seu ápice às 23h, enquanto o menor volume se concentra na madrugada entre 01h e 05h.

## 5. Alguém batendo na porta

```bash
awk '$7 ~ /\/(admin|\.env|\.git|wp-login|phpmyadmin)/ {print $0}' dados/access.log | wc -l
awk '$7 ~ /\/(admin|\.env|\.git|wp-login|phpmyadmin)/ {print $1}' dados/access.log | sort -u | wc -l
awk '$7 ~ /\/(admin|\.env|\.git|wp-login|phpmyadmin)/ {print $9}' dados/access.log | sort | uniq -c

```

```
2080
2
2080 404

```

**Leitura:** Foram registradas 2.080 tentativas de acesso a caminhos sensíveis (como `.env`, `.git`, `/admin`, etc.), originadas de apenas 2 IPs distintos. O servidor respondeu com o código HTTP 404 (Not Found) a todas as tentativas, confirmando que os alvos da varredura automatizada não estavam expostos.

## Conclusão: minha primeira ação como operador de plantão

Como operador de plantão, minha primeira ação imediata seria **bloquear o IP `203.0.113.47` no firewall da aplicação (ou via regra de drop/deny no Nginx / Security Group)**. Os dados comprovaram que este único IP é responsável por 88.400 requisições automatizadas via `curl` no endpoint de busca, sobrecarregando o servidor e consumindo recursos desnecessariamente na hora de pico (23h), além de agravar o cenário de instabilidade visto em rotas pesadas como a de geração de relatórios.
