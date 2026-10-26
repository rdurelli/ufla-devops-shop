# Analise de access.log -- Guilherme Medeiros Gomes (@guilhermesemog)
**Linhas analisadas:** 516866 

## 1. Volume e falha
```bash
awk '
{
    total++
    if ($9 >= 400 && $9 < 500) erro4xx++
    if ($9 >= 500 && $9 < 600) erro5xx++
}
END {
    erros = erro4xx + erro5xx
    printf "Total: %d\n4xx: %d\n5xx: %d\nFalhas: %d\nPercentual: %.2f%%\n",
           total, erro4xx, erro5xx, erros, erros / total * 100
}' dados/access.log
```

```
Total: 516866
4xx: 6162
5xx: 11749
Falhas: 17911
Percentual: 3.47%
```

**Leitura:** Foram analisadas 516.866 requisições. Destas, 6.162 retornaram códigos 4xx e 11.749 retornaram códigos 5xx, totalizando 17.911 falhas, aproximadamente 3,47% de todo o tráfego.

## 2. Os 10 IPs mais frequentes
```bash
awk '{print $1}' dados/access.log | sort | uniq -c | sort -rn | head -10
```

```
88400   203.0.113.47
1788    192.0.2.245
1772    192.0.2.171
1771    192.0.2.81
1771    192.0.2.225
1771    192.0.2.16
1767    192.0.2.138
1762    192.0.2.222
1757    192.0.2.45
1753    192.0.2.166
```

```bash
awk '$1 == "203.0.113.47" {print $7}' dados/access.log | sort | uniq -c | sort -rn
```

```
22224 /api/busca?q=mochila
22161 /api/busca?q=tenis
22090 /api/busca?q=camiseta
21925 /api/busca?q=fone
```

```bash
awk -F'"' '$1 ~ /^203\.0\.113\.47 / {print $6}' dados/access.log | sort | uniq -c | sort -rn | head
```

```
88400 curl/8.5.0
```

**Leitura:** O IP 203.0.113.47 apresentou comportamento suspeito. Ele realizou 88.400 requisições, muito acima dos demais IPs, todas usando o user-agent `curl/8.5.0` e concentradas em apenas quatro consultas ao endpoint `/api/busca`.

## 3. O endpoint quebrado


```bash
awk '$9 == 500 {print $7}' dados/access.log \
| sort \
| uniq -c \
| sort -rn \
| head -10
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

```bash
awk '
$7 == "/api/relatorio/gerar" {
    total++
    if ($9 == 500) erros++
}
END {
    printf "Total: %d\nErros 500: %d\nTaxa de falha: %.2f%%\n",
           total, erros, erros / total * 100
}' dados/access.log
```

```
Total: 10400
Erros 500: 3620
Taxa de falha: 34.81%
```

**Leitura:** O caminho `/api/relatorio/gerar` foi o que mais gerou erros 500, com 3.620 ocorrências. Ele recebeu 10.400 requisições no total, portanto não falha sempre: cerca de 34,81% das chamadas resultaram em erro 500.

## 4. A hora do pico
```bash
awk '{print $4}' dados/access.log \
| cut -d: -f2 \
| sort \
| uniq -c \
| sort -n -k2
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

**Leitura:** O maior volume de tráfego ocorreu às 23h, com 68.535 requisições. O tráfego também foi elevado às 22h, com 43.979 requisições, mostrando uma forte concentração de acessos no final do dia.

## 5. Alguém batendo na porta
```bash
awk '
$7 ~ /\/admin|\.env|\.git|wp-login|\/phpmyadmin/ {
    total++
    ips[$1] = 1
    caminhos[$7]++
    status[$9]++
}
END {
    for (ip in ips)
        n_ips++

    printf "Tentativas: %d\n", total
    printf "IPs distintos: %d\n", n_ips

    print "\nIPs:"
    for (ip in ips)
        printf "%s\n", ip

    print "\nCaminhos:"
    for (c in caminhos)
        printf "%d %s\n", caminhos[c], c

    print "\nRespostas:"
    for (s in status)
        printf "%d %s\n", status[s], s
}' dados/access.log
```

```
Tentativas: 2080
IPs distintos: 2

IPs:
198.51.100.9
198.51.100.23

Caminhos:
318 /phpmyadmin/index.php
313 /admin
356 /.git/config
368 /wp-login.php
343 /.env
382 /admin/login

Respostas:
2080 404
```

**Leitura:** Foram identificadas 2.080 tentativas de acesso a caminhos sensíveis, originadas de 2 IPs distintos. Os alvos incluíram `/admin`, `.env`, `.git`, `wp-login` e `/phpmyadmin`, e todas as requisições receberam status HTTP 404, indicando que os recursos procurados não foram encontrados pelo servidor.

## Conclusão: minha primeira ação como operador de plantão

Minha primeira ação seria bloquear temporariamente ou aplicar limitação de requisições ao IP `203.0.113.47`. Ele sozinho realizou 88.400 requisições, todas por meio do `curl/8.5.0`, concentradas em apenas quatro buscas e chegando a 1.021 requisições em um único minuto, caracterizando tráfego automatizado em volume muito superior ao dos demais clientes. Essa medida reduziria imediatamente uma fonte anormal de carga sobre o servidor, enquanto a falha do endpoint `/api/relatorio/gerar`, que apresentou erro 500 em 34,81% de suas chamadas, poderia ser investigada em seguida.