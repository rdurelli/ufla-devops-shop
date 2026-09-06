# Analise de access.log -- Gabriel Jardim de Souza (@gabriel-jardim-de-souza)

**Linhas analisadas:** 516866

## 1. Volume e falha

```bash
awk '{total++; if ($9 >= 400 && $9 < 500) erro4xx++; if ($9 >= 500 && $9 < 600) erro5xx++} END {printf "Total: %d\n4xx: %d (%.2f%%)\n5xx: %d (%.2f%%)\n", total, erro4xx, erro4xx/total*100, erro5xx, erro5xx/total*100}' dados/access.log
```

```bash
Total: 516866
4xx: 6162 (1,19%)
5xx: 11749 (2,27%)
```

**Leitura:** O log possui 516866 requisições. Cerca de 1,19% do total (6162) resultaram em erros 4xx e 2,27% (11749) resultaram em erros 5xx.

## 2. Os 10 IPs mais frequentes

```bash
awk '{print $1}' dados/access.log | sort | uniq -c | sort -rn | head -10
```

```bash
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
grep '^203.0.113.47' dados/access.log | awk '{print $7}' | sort | uniq -c | sort -rn | head -5
```

```bash
22224 /api/busca?q=mochila
22161 /api/busca?q=tenis
22090 /api/busca?q=camiseta
21925 /api/busca?q=fone
```

```bash
grep '^203.0.113.47' dados/access.log | awk '{print $4}' | cut -d: -f2 | sort | uniq -c
```

```bash
30940 22
57460 23
```

```bash
grep '^203.0.113.47' dados/access.log | awk -F'"' '{print $6}' | sort | uniq -c | sort -rn | head -5
```

```bash
88400 curl/8.5.0
```

**Leitura:** O IP 203.0.113.47 fez 88400 requisições, bem mais que os outros IPs. A maioria dos acessos foi para buscas de produtos, principalmente entre 22h e 23h, usando curl/8.5.0, o que indica que provavelmente eram requisições automatizadas.

## 3. Endpoint quebrado

```bash
awk '$9 == 500 {print $7}' dados/access.log | sort | uniq -c | sort -rn | head -1
```

```bash
3620 /api/relatorio/gerar
```

```bash
awk '$7 == "/api/relatorio/gerar" {total++; if ($9 == 500) erros++} END {printf "Total: %d\nErros 500: %d (%.2f%%)\n", total, erros, erros/total*100}' dados/access.log
```

```bash
Total: 10400
Erros 500: 3620 (34,81%)
```

**Leitura:** O endpoint /api/relatorio/gerar teve 3620 erros 500 em 10400 requisições, representando 34,81% do total. Então, ele não falha sempre, mas apresenta uma quantidade considerável de erros.

## 4. A hora do pico

```bash
awk '{print $4}' dados/access.log | cut -d: -f2 | sort | uniq -c
```

```bash
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

**Leitura:** O horário com mais requisições foi 23h, com 68535 acessos. Às 22h também houve um volume alto, com 43979 requisições.

## 5. Alguém batendo na porta

```bash
grep -E '/admin|\.env|\.git|wp-login|/phpmyadmin' dados/access.log | wc -l
```

```bash
2080
```

```bash
grep -E '/admin|\.env|\.git|wp-login|/phpmyadmin' dados/access.log | awk '{print $1}' | sort | uniq | wc -l
```

```bash
2
```

```bash
grep -E '/admin|\.env|\.git|wp-login|/phpmyadmin' dados/access.log | awk '{print $9}' | sort | uniq -c | sort -rn
```

```bash
2080 404
```

**Leitura:** Foram encontradas 2080 tentativas de acesso a caminhos sensíveis, feitas por 2 IPs diferentes. Todas tiveram resposta 404, ou seja, os caminhos acessados não foram encontrados.

## Conclusao: minha primeira acao como operador de plantao

Como primeira ação, eu bloquearia temporariamente o IP 203.0.113.47, pois ele fez 88400 requisições, um número muito maior que os outros IPs. Além disso, os acessos ficaram concentrados entre 22h e 23h, foram feitos com curl/8.5.0 e principalmente para o endpoint de busca, o que indica que provavelmente eram requisições automatizadas e poderiam estar contribuindo para a lentidão do servidor.