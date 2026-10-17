# Analise de access.log

**Linhas analisadas:** 516866

## 1. Volume e falha

```bash
awk '{
    total++
    if ($9 ~ /^4[0-9][0-9]$/) erro4++
    if ($9 ~ /^5[0-9][0-9]$/) erro5++
}
END {
    printf "Total: %d\n", total
    printf "4xx: %d (%.2f%%)\n", erro4, erro4/total*100
    printf "5xx: %d (%.2f%%)\n", erro5, erro5/total*100
    printf "Total de falhas: %d (%.2f%%)\n", erro4+erro5, (erro4+erro5)/total*100
}' dados/access.log
```

```text
Total: 516866
4xx: 6162 (1.19%)
5xx: 11749 (2.27%)
Total de falhas: 17911 (3.47%)
```

**Leitura:** O log tem 516.866 requisições no total. Dessas, 6.162 retornaram erro 4xx, representando 1,19%, e 11.749 retornaram erro 5xx, representando 2,27%. Juntando os dois tipos de erro, 3,47% das requisições falharam. Também dá pra perceber que os erros 5xx aconteceram mais vezes que os 4xx.

## 2. Os 10 IPs mais frequentes

Para encontrar os 10 IPs que mais fizeram requisições:

```bash
awk '{print $1}' dados/access.log | sort | uniq -c | sort -rn | awk 'NR <= 10'
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

O IP `203.0.113.47` chamou bastante atenção, então verifiquei quais caminhos ele estava acessando:

```bash
awk '$1 == "203.0.113.47" {print $7}' dados/access.log | sort | uniq -c | sort -rn | awk 'NR <= 20'
```

```text
22224 /api/busca?q=mochila
22161 /api/busca?q=tenis
22090 /api/busca?q=camiseta
21925 /api/busca?q=fone
```

Também verifiquei o user-agent utilizado por esse IP:

```bash
awk -F'"' '$1 ~ /^203\.0\.113\.47 / {print $6}' dados/access.log | sort | uniq -c | sort -rn
```

```text
88400 curl/8.5.0
```

Por fim, verifiquei o ritmo das requisições por minuto:

```bash
awk '$1 == "203.0.113.47" {print $4}' dados/access.log | cut -d: -f1-3 | sort | uniq -c | sort -rn | awk 'NR <= 20'
```

```text
1021 [14/Aug/2026:23:44
1017 [14/Aug/2026:23:00
1015 [14/Aug/2026:23:32
1007 [14/Aug/2026:23:21
1002 [14/Aug/2026:23:17
 995 [14/Aug/2026:23:53
 994 [14/Aug/2026:23:33
 993 [14/Aug/2026:23:28
 992 [14/Aug/2026:23:55
 991 [14/Aug/2026:23:22
 983 [14/Aug/2026:23:42
 981 [14/Aug/2026:23:39
 979 [14/Aug/2026:23:52
 979 [14/Aug/2026:23:14
 978 [14/Aug/2026:23:25
 976 [14/Aug/2026:23:08
 974 [14/Aug/2026:23:05
 971 [14/Aug/2026:23:35
 970 [14/Aug/2026:23:04
 969 [14/Aug/2026:23:43
```

**Leitura:** O IP `203.0.113.47` apresenta um comportamento bem diferente dos outros. Ele fez 88.400 requisições, enquanto os outros IPs mais frequentes ficaram na faixa de 1.700. Além disso, ele acessou somente quatro buscas diferentes e todas as requisições foram feitas usando `curl/8.5.0`. O ritmo também foi muito alto, chegando a 1.021 requisições em um único minuto. Por isso, parece ser algum tipo de acesso automatizado e considero esse IP suspeito.

## 3. O endpoint quebrado

```bash
awk '{
    total[$7]++

    if ($9 == 500)
        erro[$7]++
}
END {
    for (caminho in erro)
        printf "%d %d %.2f%% %s\n",
            erro[caminho],
            total[caminho],
            erro[caminho] / total[caminho] * 100,
            caminho
}' dados/access.log | sort -rn | awk 'NR == 1'
```

```text
3620 10400 34.81% /api/relatorio/gerar
```

**Leitura:** O caminho que mais retornou erro 500 foi `/api/relatorio/gerar`. Ele teve 3.620 erros em 10.400 requisições, dando uma taxa de erro de 34,81%. Então ele não quebra sempre, mas falha em aproximadamente uma de cada três requisições.

## 4. A hora do pico

```bash
awk '{print $4}' dados/access.log | cut -d: -f2 | sort | uniq -c
```

```text
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

**Leitura:** A hora com mais tráfego foi 23h, com 68.535 requisições. Também dá pra perceber um aumento forte no final do dia, já que às 21h foram 15.577 requisições, às 22h subiu para 43.979 e às 23h chegou ao maior valor.

## 5. Alguem batendo na porta

Primeiro verifiquei a quantidade de tentativas, quantos IPs diferentes participaram e quais status o servidor respondeu:

```bash
awk '
$7 ~ /(\/admin|\.env|\.git|wp-login|\/phpmyadmin)/ {
    total++
    ips[$1] = 1
    status[$9]++
}
END {
    for (ip in ips)
        qtd_ips++

    print "Tentativas:", total
    print "IPs distintos:", qtd_ips

    for (s in status)
        print "Status", s ":", status[s]
}' dados/access.log
```

```text
Tentativas: 2080
IPs distintos: 2
Status 404: 2080
```

Depois verifiquei quais caminhos estavam sendo acessados:

```bash
awk '$7 ~ /(\/admin|\.env|\.git|wp-login|\/phpmyadmin)/ {print $7}' dados/access.log | sort | uniq -c | sort -rn
```

```text
382 /admin/login
368 /wp-login.php
356 /.git/config
343 /.env
318 /phpmyadmin/index.php
313 /admin
```

Também verifiquei quais IPs fizeram essas tentativas:

```bash
awk '$7 ~ /(\/admin|\.env|\.git|wp-login|\/phpmyadmin)/ {print $1}' dados/access.log | sort | uniq -c | sort -rn
```

```text
1053 198.51.100.9
1027 198.51.100.23
```

**Leitura:** Foram encontradas 2.080 tentativas de acesso a caminhos sensíveis, feitas por apenas dois IPs. Eles tentaram acessar caminhos como `/admin`, `.env`, `.git/config`, `wp-login.php` e `phpmyadmin`. Todas as tentativas receberam status 404, então nenhum desses recursos foi encontrado pelo servidor.

## Conclusao: minha primeira acao como operador de plantao

Minha primeira ação seria bloquear temporariamente o IP `203.0.113.47` e investigar de onde esse tráfego está vindo. Ele fez 88.400 requisições usando `curl`, acessando sempre os mesmos tipos de busca e chegando a mais de 1.000 requisições em um único minuto. Esse comportamento parece automatizado e pode estar aumentando a carga do servidor. Depois disso, eu verificaria o endpoint `/api/relatorio/gerar`, já que ele apresentou 3.620 erros 500 em 10.400 requisições.