# Analise de access.log -- Jose Acerbi Almeida Neto (@JoseJaan)

**Linhas analisadas:** 516866

```bash
wc -l dados/access.log
```
```
516866 dados/access.log
```

Ambiente: Ubuntu 24.04 sobre WSL2. 

## 1. Volume e falha

```bash
awk '{total++} $9 ~ /^4[0-9][0-9]$/ {c4++} $9 ~ /^5[0-9][0-9]$/ {c5++} END {printf "Total: %d\n4xx:   %d (%.2f%%)\n5xx:   %d (%.2f%%)\n", total, c4, c4*100/total, c5, c5*100/total}' dados/access.log
```
```
Total: 516866
4xx:   6162 (1.19%)
5xx:   11749 (2.27%)
```

Distribuicao completa dos códigos:

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

**Leitura:** de 516.866 requisições, 6.162 falharam com 4xx (1,19%) e 11.749 com
5xx (2,27%), somando 3,46% de respostas ruins. Há mais 503 (6.900) do que 500 (4.849), ou seja, o servidor recusou mais
requisições por indisponibilidade do que quebrou por erro interno.

**Sobre contar pelo campo certo.** Contar erro 500 por texto solto infla o numero,
porque `500` tambem aparece no campo `$10`, o tamanho da resposta:

```bash
grep -c ' 500 ' dados/access.log
```
```
4921
```

São 4.921 contra os 4.849 reais do campo `$9`: **72 falsos positivos**, todos
requisições bem-sucedidas que devolveram exatamente 500 bytes.

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

**Leitura:** `203.0.113.47` é suspeito. Do
segundo ao decimo colocado há um intervalo entre 1.753 e 1.788 requisições, variação
de 2%, que é o comportamento esperado de usuários distribuídos. O primeiro
colocado faz **49 vezes** o volume do segundo e sozinho responde por 17,1% de
todo o tráfego do dia. 

As três perguntas do enunciado (o que pedia, em que ritmo, com que user-agent):

```bash
awk '$1=="203.0.113.47" {ua=""; for(i=12;i<=NF;i++) ua=ua" "$i; print ua}' dados/access.log | sort | uniq -c | sort -rn
```
```
  88400  "curl/8.5.0"
```

```bash
awk '$1=="203.0.113.47" {print $7}' dados/access.log | sed 's/?.*//' | sort | uniq -c | sort -rn
```
```
  88400 /api/busca
```

```bash
awk '$1=="203.0.113.47" {print substr($4,14,5)}' dados/access.log | sort | uniq -c | sort -rn | head -5
```
```
   1021 23:44
   1017 23:00
   1015 23:32
   1007 23:21
   1002 23:17
```

Primeira: 100% das 88.400 requisições vieram de `curl/8.5.0`, sem uma única sessão de navegador,
quando todo o resto do log e Safari, Chrome e iPhone. 
Segunda: 100% foram para um
único endpoint, `/api/busca`, sem jamais carregar `/static/app.js` ou
`/favicon.ico`, que qualquer navegador buscaria junto. 
Terceira: o ritmo é de
aproximadamente 1.000 requisições por minuto, cerca de 17 por segundo, sustentado
e regular, coisa que humano não faz. Quarta:
```bash
awk '$1=="203.0.113.47" {print $7}' dados/access.log | sed 's/.*q=//' | sort | uniq -c | sort -rn
```
```
  22224 mochila
  22161 tênis
  22090 camiseta
  21925 fone
```

Quatro termos apenas, repetidos 22 mil vezes cada, com diferenca de 1,4% entre o
maior e o menor. É um laço iterando sobre uma lista fixa de quatro palavras. Um
humano buscando produtos gera cauda longa de termos; isto gera um retângulo.

Por fim, o servidor reagiu:

```bash
awk '$9==503 {print $1}' dados/access.log | sort | uniq -c | sort -rn
```
```
   6900 203.0.113.47
```

**Os 6.900 codigos 503 do log inteiro foram para esse IP e para mais ninguém.**
Existe rate limiting ativo e ele funcionou, 7,8% das requisições do abusador
foram recusadas, e nenhum outro cliente recebeu 503. A inundação foi contida.

## 3. O endpoint quebrado

```bash
awk '$9==500 {print $7}' dados/access.log | sed 's/?.*//' | sort | uniq -c | sort -rn | head -5
```
```
   3620 /api/relatorio/gerar
    228 /
    167 /api/produtos
    160 /produtos
    150 /produtos/detalhe
```

A pergunta pede se ele quebra sempre ou as vezes, o que exige comparar os erros
com o total daquele mesmo caminho. Um único `awk` guarda os dois contadores:

```bash
awk '{p=$7; sub(/\?.*/,"",p); tot[p]++; if($9==500) e[p]++} END {for(k in e) printf "%-24s %6d de %6d = %5.2f%%\n", k, e[k], tot[k], e[k]*100/tot[k]}' dados/access.log | sort -k5,5 -rn | head -6
```
```
/api/relatorio/gerar      3620 de  10400 = 34.81%
/produtos/detalhe          150 de  45541 =  0.33%
/api/produtos              167 de  52100 =  0.32%
/checkout                   41 de  13083 =  0.31%
/static/app.css            117 de  39266 =  0.30%
/health                     29 de   9823 =  0.30%
```

**Leitura:** `/api/relatorio/gerar` quebra às vezes, mas com frequência
altíssima, 34,81%. A comparação com o resto é o
que dá sentido ao número, todos os outros caminhos ficam entre 0,22% e 0,33%, um
piso de ruído uniforme que parece ser a taxa de falha ambiente da aplicação. O
endpoint de relatório está mais de 100 vezes acima desse piso, o que descarta
causa compartilhada (banco, rede, host) e aponta para defeito no próprio codigo
dele. Falha intermitente nessa proporção costuma ser timeout, concorrência ou
dependência externa instável, e não bug determinístico, que daria 100%.

Quando isso acontece ao longo do dia:

```bash
awk '$9==500 && $7 ~ /^\/api\/relatorio\/gerar/ {print substr($4,14,2)}' dados/access.log | sort | uniq -c | sort -k2,2n
```
```
     38 00
     18 01
      9 02
      6 03
     16 04
      3 05
     35 06
     85 07
    157 08
    222 09
    244 10
    271 11
    287 12
    279 13
    245 14
    271 15
    270 16
    222 17
    234 18
    203 19
    166 20
    119 21
    119 22
    101 23
```

Não há pico nem janela: o volume de erros acompanha o volume de tráfego hora a
hora, o que confirma taxa constante e não evento pontual. A primeira falha é às
`00:00:02` e a última às `23:59:36`. Esse endpoint está quebrado nas 24 horas do
log.

Quantos usuarios distintos isso atingiu:

```bash
awk '$9==500 && $7 ~ /^\/api\/relatorio\/gerar/ {print $1}' dados/access.log | sort -u | wc -l
```
```
254
```

O log tem 257 IPs distintos. Tirando o abusador da pergunta 2 e os dois
escaneadores da pergunta 5, sobram exatamente 254 usuarios reais. Todos eles
receberam pelo menos um erro 500 nesse endpoint.

## 4. A hora do pico

```bash
awk '{print $4}' dados/access.log | cut -d: -f2 | sort | uniq -c | sort -k2,2n
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

**Leitura:** a resposta literal é 23h, com 68.535 requisições, seguida de 22h
com 43.979. Mas esse pico é artificial, e a distribuicao completa é justamente o
que denuncia isso. Da 00h as 21h o log desenha uma curva de uso humano coerente,
vale de madrugada (1.471 as 03h), subida a partir das 07h, platô de trabalho entre
10h e 16h com dois cumes de cerca de 32.500 as 11h e as 15h, queda suave a noite
ate 15.577 as 21h. Então, as 22h, o trafego triplica e as 23h quadruplica, contra
a tendência de queda. 

Removendo o IP da pergunta 2:

```bash
awk '$1!="203.0.113.47" {print substr($4,14,2)}' dados/access.log | sort | uniq -c | sort -k2,2n | tail -8
```
```
  30886 16
  28575 17
  25996 18
  22807 19
  18860 20
  15577 21
  13039 22
  11075 23
```

A anomalia desaparece por completo e a curva volta a cair suavemente (15.577,
depois 13.039, depois 11.075). O pico real de trafego legétimo é às 11h e às
15h, com cerca de 32.500 requisições; o pico das 23h é um único cliente
automatizado.

## 5. Alguem batendo na porta

```bash
awk '$7 ~ /admin|\.env|\.git|wp-login|phpmyadmin/ {print $7}' dados/access.log | sed 's/?.*//' | sort | uniq -c | sort -rn
```
```
    382 /admin/login
    368 /wp-login.php
    356 /.git/config
    343 /.env
    318 /phpmyadmin/index.php
    313 /admin
```

Quantidade, IPs distintos e resposta do servidor:

```bash
awk '$7 ~ /admin|\.env|\.git|wp-login|phpmyadmin/ {n++; ip[$1]; st[$9]++} END {printf "tentativas: %d\n", n; k=0; for(i in ip) k++; printf "IPs distintos: %d\n", k; for(s in st) printf "status %s: %d\n", s, st[s]}' dados/access.log
```
```
tentativas: 2080
IPs distintos: 2
status 404: 2080
```

Quem são e com que ferramenta:

```bash
awk '$7 ~ /admin|\.env|\.git|wp-login|phpmyadmin/ {ua=""; for(i=12;i<=NF;i++) ua=ua" "$i; print $1, ua}' dados/access.log | sort | uniq -c | sort -rn
```
```
   1053 198.51.100.9  "python-requests/2.32.3"
   1027 198.51.100.23  "python-requests/2.32.3"
```

Quando:

```bash
awk '$7 ~ /admin|\.env|\.git|wp-login|phpmyadmin/ {print substr($4,14,2)}' dados/access.log | sort | uniq -c | sort -k2,2n
```
```
    518 02
    497 03
    518 04
    547 05
```

**Leitura:** houve 2.080 tentativas contra 6 caminhos sensíveis, vindas de 2 IPs
(`198.51.100.9` e `198.51.100.23`), e o servidor respondeu 404 a todas as 2.080,
sem um único 200, 401 ou 403. Nada foi encontrado e nada vazou. Três detalhes
sustentam a leitura de varredura automatizada, e não de ataque dirigido. Os
seis caminhos aparecem em quantidades quase iguais, entre 313 e 382. O 
user-agent é `python-requests/2.32.3` nos dois IPs, o mesmo script rodando
de dois lugares. A atividade é integralmente entre 02h e 05h, a janela de
menor tráfego legítimo do log, quando a varredura se esconde melhor no ruído.

## Conclusao: minha primeira ação como operador de plantão

Minha primeira ação não seria bloquear `203.0.113.47`, e essa é a decisao que
os dados mudaram. A inundação é o evento mais barulhento do log, 88 mil
requisições e o tráfego quadruplicado às 23h, mas não estava impactando outros usuários.

O que esta realmente machucando é `/api/relatorio/gerar`, e por isso a
primeira ação seria abrir incidente e reverter a ultima implantação desse
endpoint, ou desativá-lo atras de uma feature flag ate haver correção. 

Na sequência, e sem urgência de madrugada, eu registraria duas pendências.
Primeiro, manter `203.0.113.47` sob observação com limite mais estrito, porque
hoje ele consome 17% da capacidade do servico de busca de graça, o que é custo e
não incidente. Segundo, as 2.080 varreduras das 02h às 05h não exigem ação
imediata, já que todas receberam 404, mas os dois IPs merecem entrar em lista de
bloqueio e o alerta de varredura merece existir, porque hoje ninguém seria avisado
se um daqueles `/.env` respondesse 200.
