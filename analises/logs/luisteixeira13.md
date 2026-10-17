# Analise de access.log -- Luis Felipe Costa Teixeira (@luisteixeira13)

**Linhas analisadas:** 516866

## 1. Volume e falha
```bash
wc -l dados/access.log
awk '$9 ~ /^4/' dados/access.log | wc -l
awk '$9 ~ /^5/' dados/access.log | wc -l
```

```
#Retorno1
516866 dados/access.log
##Retorno2
6162
##Retorno3
11749
```
**Leitura:** O log contém um total de 516.866 requisições. Deste volume, 6.162 (aproximadamente 1,19%) resultaram em falhas 4xx (problemas na requisição do cliente), e 11.749 (cerca de 2,27%) resultaram em erros 5xx (problemas no servidor). No total, os erros representam cerca de 3,46% do tráfego. A taxa de erros 5xx (mais do dobro dos erros 4xx) chama a atenção, indicando que o servidor está ativamente quebrando para uma parcela considerável do tráfego.

## 2. Quem Bateu Mais

```bash
awk '{print $1}' dados/access.log | sort | uniq -c | sort -rn | head -n 10
awk '$1 == "203.0.113.47" {print $7}' dados/access.log | sort | uniq -c | sort -rn | head -n 5
grep '^203.0.113.47' dados/access.log | cut -d'"' -f6 | sort | uniq -c | sort -rn | head -n 5
```
```
#Retorno1
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

#Retorno2
22224 /api/busca?q=mochila
22161 /api/busca?q=tenis
22090 /api/busca?q=camiseta
21925 /api/busca?q=fone

#Retorno3
88400 curl/8.5.0 

```

**Leitura:** O IP 203.0.113.47 é extremamente suspeito. Ele gerou 88.400 requisições, o que é cerca de 50 vezes mais tráfego que o segundo IP mais frequente. Investigando mais a fundo este IP específico, notamos que 100% de seus acessos usam o User-Agent curl/8.5.0 e marretam exclusivamente o endpoint /api/busca com termos repetitivos. Trata-se de um bot automatizado, possivelmente fazendo scraping (raspagem de dados) ou tentando sobrecarregar o banco de dados através das buscas.

## 3. O endpoint quebrado
```bash
awk '$9 == "500" {print $7}' dados/access.log | sort | uniq -c | sort -rn | head -n 5
awk '$7 == "/api/relatorio/gerar"' dados/access.log | wc -l
```

```
##Retorno1
3620 /api/relatorio/gerar
    228 /
    167 /api/produtos
    160 /produtos
    150 /produtos/detalhe

##retorno 2
10400
```

**Leitura:**O caminho que mais gera erros 500 é o /api/relatorio/gerar, com 3.620 ocorrências. Comparando com o total de requisições para este mesmo caminho (10.400), notamos que ele não falha 100% das vezes, mas sim em cerca de 34,8% das tentativas. Isso indica que a quebra é intermitente, provavelmente associada a gargalos de performance (como relatórios pesados estourando o tempo limite) ou condições específicas dos dados solicitados.


## 4. A hora do pico
```bash
awk '{print $4}' dados/access.log | cut -d: -f2 | sort | uniq -c | sort -rn
```
```
#Retorno1
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
**Leitura:**O tráfego apresenta um pico extremo no final da noite, especificamente às 23h (68.535 requisições) e 22h (43.979). Durante o horário comercial, a média se mantém na faixa de 25k a 32k requisições por hora. Esse comportamento noturno anômalo está diretamente ligado ao ataque/scraping do IP suspeito identificado anteriormente, que concentrou suas dezenas de milhares de requisições neste período.

## 5. Alguém batendo na porta
```bash
awk '$7 ~ /(\/admin|\.env|\.git|wp-login|phpmyadmin)/ {print $9}' dados/access.log | sort | uniq -c
awk '$7 ~ /(\/admin|\.env|\.git|wp-login|phpmyadmin)/ {print $1}' dados/access.log | sort | uniq | wc -l
```
```
#Retorno1
2080 404
#Retorno2
2
```
**Leitura:** Foram registradas 2.080 tentativas de acesso a caminhos sensíveis, originadas de apenas 2 IPs distintos. Isso configura uma varredura automatizada (scanners de vulnerabilidades) buscando brechas conhecidas (como wp-login ou arquivos .env). O servidor lidou bem com a situação, retornando o status HTTP 404 (Not Found) para 100% dessas requisições, o que indica que esses arquivos não estão expostos ou não existem na aplicação.



se você fosse o operador de plantão nesta madrugada, qual seria a sua primeira ação, e por quê? Uma ação concreta — bloquear, escalar, reverter, avisar alguém — justificada pelo que os dados mostraram.

**R:** Considerando as análises realizadas para diagnosticar a causa da lentidão, minha primeira ação concreta como operador de plantão (assumindo ter as permissões necessárias) seria realizar o bloqueio imediato do IP `203.0.113.47` no firewall. Os logs justificam essa decisão: este IP originou mais de 88 mil requisições automatizadas, sendo o responsável direto pela sobrecarga e lentidão do servidor. Logo após mitigar o incidente, eu geraria um relatório com essas evidências para a supervisão, incluindo também um alerta sobre o gargalo no endpoint `/api/relatorio/gerar`, que está quebrando de forma intermitente, para que a equipe de engenharia possa investigar a causa raiz no horário comercial.
