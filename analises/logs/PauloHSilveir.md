# Analise de access.log -- Paulo Henrique Silveira (@PauloHSilveir)

**Linhas analisadas:** 516866 dados/access.log

## 1. Volume e falha

```bash
awk '{ 
    total++ 
    if ($9 >= 400 && $9 < 500) erro4++ 
    if ($9 >= 500 && $9 < 600) erro5++ 
} END { 
    print "Total:", total 
    print "4xx:", erro4, "-", erro4/total*100 "%" 
    print "5xx:", erro5, "-", erro5/total*100 "%" 
}' dados/access.log | awk '{print}'
```

```text
Total: 516866
4xx: 6162 - 1,19219%
5xx: 11749 - 2,27312%
```

**Leitura:** O log tem 516.866 requisições. Foram 6.162 respostas 4xx (1,19%) e 11.749 respostas 5xx (2,27%); juntas, elas representam 17.911 requisições, ou 3,47% do total.

## 2. Os 10 IPs mais frequentes

```bash
# 2.1 10 IPs mais frequentes

awk '{print $1}' dados/access.log | sort | uniq -c | sort -nr | awk 'NR<=10 {print}'
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

O IP `203.0.113.47` chamou atenção pela grande quantidade de acessos. Para entender se o comportamento era suspeito, verifiquei os caminhos acessados, o ritmo das requisições e o User-Agent.

```bash
# 2.2 Caminhos acessados

awk '$1=="203.0.113.47" {print $7}' dados/access.log | sort | uniq -c | sort -nr | awk 'NR <= 15 {print}'
```

```text
22224 /api/busca?q=mochila
22161 /api/busca?q=tenis
22090 /api/busca?q=camiseta
21925 /api/busca?q=fone
```

```bash
# 2.3 Ritmo das requisições

awk '$1=="203.0.113.47" {print $4}' dados/access.log | cut -d: -f1-3 | sort | uniq -c | sort -nr | awk 'NR <= 10'
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
```

```bash
# 2.4 User-Agent utilizado

awk '$1=="203.0.113.47"' dados/access.log | awk -F'"' '{print $6}' | sort | uniq -c | sort -nr
```

```text
88400 curl/8.5.0
```

**Leitura:** O IP `203.0.113.47` apresenta um comportamento suspeito e provavelmente automatizado. Suas 88.400 requisições foram feitas apenas para quatro buscas no endpoint `/api/busca`, chegando a mais de 1.000 requisições por minuto. Além disso, todas utilizaram o User-Agent `curl/8.5.0`, reforçando que os acessos não parecem ter sido feitos manualmente por um usuário comum.

## 3. O endpoint quebrado

```bash
awk '$9==500 {print $7}' dados/access.log | sort | uniq -c | sort -nr | awk 'NR==1 {print}'

awk '$7=="/api/relatorio/gerar" { 
    total++ 
    if ($9==500) erro++ 
} END { 
    print "Total:", total 
    print "Erros 500:", erro 
    print "Percentual de erro:", erro/total*100 "%" 
}' dados/access.log
```

```text
   3620 /api/relatorio/gerar

Total: 10400
Erros 500: 3620
Percentual de erro: 34,8077%
```

**Leitura:** `/api/relatorio/gerar` foi o caminho com mais erros 500. Ele não quebra sempre: das 10.400 chamadas, 3.620 falharam com 500 (34,81%).

## 4. A hora do pico

```bash
# Por hora
awk '{print $4}' dados/access.log | cut -d: -f2 | sort | uniq -c | sort -k2
# Vencedor
awk '{print $4}' dados/access.log | cut -d: -f2 | sort | uniq -c | sort -nr | awk 'NR==1'
```

```text
# Distribuição por hora
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
# Hora com maior tráfego
  68535 23
```

**Leitura:** O pico ocorreu entre 23h00 e 23h59, com 68.535 requisições. O salto das 22h às 23h coincide com a atividade concentrada do IP suspeito identificado na seção 2.

## 5. Alguem batendo na porta

```bash
# 5.1 Quantidade total de tentativas
grep -Ei '(/admin|\.env|\.git|wp-login|/phpmyadmin)' dados/access.log | wc -l

# 5.2 Quantidade de IPs diferentes
grep -Ei '(/admin|\.env|\.git|wp-login|/phpmyadmin)' dados/access.log | awk '{print $1}' | sort | uniq | wc -l

# 5.3 Respostas dadas pelo servidor
grep -Ei '(/admin|\.env|\.git|wp-login|/phpmyadmin)' dados/access.log | awk '{print $9}' | sort | uniq -c | sort -nr

# 5.4 Caminhos foram mais procurados:
grep -Ei '(/admin|\.env|\.git|wp-login|/phpmyadmin)' dados/access.log | awk '{print $7}' | sort | uniq -c | sort -nr

# 5.5 qtd tentativas contra caminhos sensíveis entre IDs distintos
grep -Ei '(/admin|\.env|\.git|wp-login|/phpmyadmin)' dados/access.log | awk '{print $1}' | sort | uniq -c | sort -nr
```

```text
# 5.1
2080

# 5.2
2

# 5.3
2080 404

# 5.4
    382 /admin/login
    368 /wp-login.php
    356 /.git/config
    343 /.env
    318 /phpmyadmin/index.php
    313 /admin

# 5.5
   1053 198.51.100.9
   1027 198.51.100.23
```

**Leitura:** Houve 2.080 tentativas de acesso a caminhos sensíveis, realizadas por apenas dois IPs e distribuídas entre seis caminhos. Todas receberam resposta 404, indicando que esses recursos não foram encontrados nas requisições observadas. A repetição de tentativas contra vários caminhos conhecidos é compatível com um padrão de varredura.

## Conclusao: minha primeira acao como operador de plantao

Minha primeira ação seria aplicar temporariamente uma limitação de requisições ao IP 203.0.113.47 e acompanhar o comportamento do serviço. Esse IP sozinho realizou 88.400 requisições, repetindo apenas quatro buscas por meio do curl e chegando a mais de 1.000 requisições por minuto. Depois de conter essa carga, eu investigaria separadamente as falhas do endpoint /api/relatorio/gerar, que apresentou erro 500 em 34,81% das chamadas.