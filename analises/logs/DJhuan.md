# Analise de access.log -- Jhuan Carlos Sabaini Dassie (@DJhuan)
**Linhas analisadas:**
```bash
❯ wc -l access.log
516866 access.log
```

## 1. Volume e falha
```bash
wc -l access.log

awk '$9 >= 400 && $9 < 500' access.log | wc -l

awk '$9 >= 500 && $9 < 600' access.log | wc -l

awk 'BEGIN {print (6162+11749)/516866*100}'
```
```bash
516866

6162

11749

3.46531
```

**Leitura:** Olhando a porcentagem do total, o acúmulo de erros 400 e 500 não parece preocupar. Entretanto, deve-se investigar o motivo das falhas do servidor.

 ## 2. Quem bateu mais
```bash
awk '{print $1}' access.log | sort -n -r | uniq -c | sort -n -r | head -10

awk '$1 == "203.0.113.47"' access.log | head -100

awk '{print $1}' access.log | awk -F. '{print $1}' | sort -n -r | uniq -c

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

# Saída muito grande para deixar completa
203.0.113.47 - - [14/Aug/2026:22:24:51 +0000] "GET /api/busca?q=tenis HTTP/1.1" 200 1279 "-" "curl/8.5.0"
203.0.113.47 - - [14/Aug/2026:22:13:01 +0000] "GET /api/busca?q=tenis HTTP/1.1" 503 203 "-" "curl/8.5.0"
203.0.113.47 - - [14/Aug/2026:22:32:10 +0000] "GET /api/busca?q=camiseta HTTP/1.1" 200 797 "-" "curl/8.5.0"
# ------------------------------------- #

  88400 203
   2080 198
 426386 192
```
**Leitura:** O que chama atenção, além do número de requisições que é alto, é que este é um dos poucos ips que não começa com 198 ou 192, além disso, isolando o início do ip, 203, vemos que todas as requisições são de uma mesma máquina, para um mesmo recurso, com sempre os mesmos parâmetros de query e em intervalos regulares. Isso pode se tratar de um robô.

## 3. Endpoint quebrado
```bash
awk '$9 == 500 {print $7}' access.log | sort -r | uniq -c | sort -n -r | head -10

awk '$7 == "/api/relatorio/gerar"' access.log | wc -l

awk 'BEGIN {print 3620/10400*100}'
```
```bash
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

10400

34.8077
```
**Leitura:** O endpoint com maior taxa de falhas foi `/api/relatorio/gerar`, com quase 35% das requisições totais falhando. Por se tratar de uma rota de geração de relatório, ao invés de uma simples resposta, o código deve ter alguma falha que levanta erro durante a feração.
 
## 4. Hora de pico
```bash
awk '{print $4}' access.log | cut -d ':' -f 2 | sort -n | uniq -c | sort -n -r
```
```bash
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
**Leitura:** O horário de pico é 23hr, com queda brusca à meia noite. O servidor recebe tráfego relativamente constante das 10hr às 17hr.

## 5. Batem à porta
```bash
awk '$7 ~ /\/admin|\.env|\.git|wp-login|\/phpmyadmin/{print $1}' access.log | wc -l

awk '$7 ~ /\/admin|\.env|\.git|wp-login|\/phpmyadmin/{print $1 " - " $9}' access.log | sort -n | uniq -c

awk '$7 ~ /\/admin|\.env|\.git|wp-login|\/phpmyadmin/{print $1 " - " $7 " - " $9}' access.log | sort -n | uniq -c
```
```bash
2080

   1053 198.51.100.9 - 404
   1027 198.51.100.23 - 404

    162 198.51.100.9 - /admin - 404
    209 198.51.100.9 - /admin/login - 404
    156 198.51.100.9 - /.env - 404
    173 198.51.100.9 - /.git/config - 404
    156 198.51.100.9 - /phpmyadmin/index.php - 404
    197 198.51.100.9 - /wp-login.php - 404
    151 198.51.100.23 - /admin - 404
    173 198.51.100.23 - /admin/login - 404
    187 198.51.100.23 - /.env - 404
    183 198.51.100.23 - /.git/config - 404
    162 198.51.100.23 - /phpmyadmin/index.php - 404
    171 198.51.100.23 - /wp-login.php - 404
```
**Leitura:** Apenas dois endereços de IP tentaram acessar rotas sensíveis, 198.51.100.9 e 198.51.100.23. Em nenhum dos casos listados houve sucesso, muito pelo contrário, a rota sequer existia, mas o que chama a atenção é a quantidade de tentativas, que é alta. 

## Conclusao:
Minha primeira ação como plantonista seria bloquear os endereços de IP: `203.0.113.47`, `198.51.100.9` e `198.51.100.23`; o primeiro por fazer repetidas requisições, em curtos intervalos e em grande número, e os outros dois por estarem buscando arquivos desprotegidos. Minha segunda ação seria informar a equipe sobre a vulnerabilidade do servidor à ataques de DoS, visto que o endereço `203.0.113.47` não foi bloqueado automaticamente. A terceira ação seria informar a equipe de desenvolvimento sobre as falhas no endpoint de geração de relatórios e que estou disposto a trabalhar em conjunto para buscar a origem dos erros.

