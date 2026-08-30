# Analise de access.log -- <Seu Nome> (@<seu-usuario>)

**Linhas analisadas:** <saida do wc -l>

## 1. Volume e falha

‘‘‘bash
awk '{
  total++
  if ($9 ~ /^4/) c4++
  if ($9 ~ /^5/) c5++
} END {
  printf "total=%d 4xx=%d (%.2f%%) 5xx=%d (%.2f%%)\n", total, c4, c4/total*100, c5, c5/total*100
}' dados/access.log
‘‘‘
‘‘‘
total=516866 4xx=6162 (1,19%) 5xx=11749 (2,27%)
‘‘‘

**Leitura:** Esse awk passa por cada linha do access.log contando o total de requisições e, para cada uma, verifica se o campo 9 (código de status) começa com "4" ou "5", somando em contadores separados (c4 e c5); ao final (END), calcula e imprime o total e os percentuais de 4xx e 5xx sobre o total.

## 2. Os 10 IPs mais frequentes

- Descobrindo os 10 IPs mais frequentes
```bash
awk '{print $1}' dados/access.log | sort | uniq -c | sort -nr | head -10
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
- Investigando o IP suspeito (203.0.113.47)

O que ele buscava?
```bash
grep "203.0.113.47" dados/access.log | awk '{print $7}' | sort | uniq -c | sort -nr | head
```
```
22224 /api/busca?q=mochila
22161 /api/busca?q=tenis
22090 /api/busca?q=camiseta
21925 /api/busca?q=fone
```

Com que frequência?
```bash
grep "203.0.113.47" dados/access.log | awk '{print $4}' | sort | uniq -c | head -20
```
```
7 [14/Aug/2026:22:00:00
9 [14/Aug/2026:22:00:01
6 [14/Aug/2026:22:00:02
11 [14/Aug/2026:22:00:03
11 [14/Aug/2026:22:00:04
11 [14/Aug/2026:22:00:05
10 [14/Aug/2026:22:00:06
11 [14/Aug/2026:22:00:07
2 [14/Aug/2026:22:00:08
15 [14/Aug/2026:22:00:09
8 [14/Aug/2026:22:00:10
8 [14/Aug/2026:22:00:11
9 [14/Aug/2026:22:00:12
8 [14/Aug/2026:22:00:13
15 [14/Aug/2026:22:00:14
4 [14/Aug/2026:22:00:15
9 [14/Aug/2026:22:00:16
11 [14/Aug/2026:22:00:17
6 [14/Aug/2026:22:00:18
4 [14/Aug/2026:22:00:19
```

**Leitura:** O IP 203.0.113.47 é claramente um bot: gerou 88.400 requisições (~50x mais que qualquer outro IP), todas concentradas em 4 buscas fixas no /api/busca, num ritmo constante de vários acessos por segundo — padrão incompatível com navegação humana.

## 3. Qual caminho causou mais erro 500

```bash
awk '$7 == "/api/relatorio/gerar" {
  total++
  if ($9 == 500) erros++
} END {
  printf "total=%d erros_500=%d taxa=%.2f%%\n", total, erros, erros/total*100
}' dados/access.log
```
```
total=10400 erros_500=3620 taxa=34,81%
```
**Leitura:** o /api/relatorio/gerar concentra o maior volume de erros 500 do log (3.620, ~15x o segundo colocado) e falha em quase 1 a cada 3 chamadas (34,81%) — uma taxa alta demais pra ser um caso de borda raro, mas baixa demais pra ser um bug que quebra sempre, o que aponta para um endpoint pesado que estoura sob certas condições de carga.


## 4. Em qual hora do dia houve mais tráfego?

- Extraindo a hora de cada requisição e olhando distribuição por volume (achar o vencedor)
```bash
awk '{print substr($4, 14, 2)}' dados/access.log | sort | uniq -c | sort -nr | head
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
```

- Distribuição completa, em ordem cronológica (00h a 23h)
```bash
awk '{print substr($4, 14, 2)}' dados/access.log | sort | uniq -c | sort -k2
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

- Confirmando se a alta de 22h-23h é explicada pelo IP suspeito (203.0.113.47)
```bash
grep "203.0.113.47" dados/access.log | awk '{print substr($4, 14, 2)}' | sort | uniq -c | sort -k2
```
```
30940 22
57460 23
```


**Leitura:** o tráfego segue uma curva humana normal da madrugada (~1.500-2.000/h) até o platô comercial das 9h-17h (~28.000-32.000/h), com queda suave à noite — mas às 22h e 23h o volume dispara para 43.979 e 68.535, quebrando essa tendência. Comparando com o IP bot identificado na pergunta 2, ele responde por 70% e 84% do tráfego nessas duas horas, respectivamente — ou seja, o "pico do dia" não é uso real, é o bot concentrando sua atividade automatizada no fim do dia e distorcendo a leitura de horário de maior demanda.

## 5. Há tentativa de acesso a caminho sensível — /admin,.env, .git, wp-login, /phpmyadmin? Quantas, de quantos IPs distintos, e o que oservidor respondeu a elas?

markdown
## 5. Tentativas de acesso a caminhos sensíveis

- Testando o padrão contra a linha inteira (checagem inicial)
```bash
grep -E "/admin|\.env|\.git|wp-login|phpmyadmin" dados/access.log | head
```
```
198.51.100.9 - - [14/Aug/2026:02:22:01 +0000] "GET /phpmyadmin/index.php HTTP/1.1" 404 268 "-" "python-requests/2.32.3"
198.51.100.23 - - [14/Aug/2026:02:32:49 +0000] "GET /admin/login HTTP/1.1" 404 160 "-" "python-requests/2.32.3"
198.51.100.23 - - [14/Aug/2026:02:06:58 +0000] "GET /.env HTTP/1.1" 404 185 "-" "python-requests/2.32.3"
198.51.100.9 - - [14/Aug/2026:02:58:58 +0000] "GET /admin HTTP/1.1" 404 177 "-" "python-requests/2.32.3"
198.51.100.23 - - [14/Aug/2026:02:52:49 +0000] "GET /wp-login.php HTTP/1.1" 404 236 "-" "python-requests/2.32.3"
198.51.100.23 - - [14/Aug/2026:02:17:35 +0000] "GET /.git/config HTTP/1.1" 404 210 "-" "python-requests/2.32.3"
```

- Contando o total de tentativas
```bash
awk '{print $7}' dados/access.log | grep -cE "/admin|\.env|\.git|wp-login|phpmyadmin"
```
```
2080
```

- Vendo quais caminhos específicos foram mais tentados
```bash
awk '{print $7}' dados/access.log | grep -E "/admin|\.env|\.git|wp-login|phpmyadmin" | sort | uniq -c | sort -nr
```
```
382 /admin/login
368 /wp-login.php
356 /.git/config
343 /.env
318 /phpmyadmin/index.php
313 /admin
```

- Contando quantos IPs distintos fizeram essas tentativas
```bash
awk '$7 ~ /\/admin|\.env|\.git|wp-login|phpmyadmin/ {print $1}' dados/access.log | sort -u | wc -l
```
```
2
```

- Verificando o que o servidor respondeu
```bash
awk '$7 ~ /\/admin|\.env|\.git|wp-login|phpmyadmin/ {print $9}' dados/access.log | sort | uniq -c | sort -nr
```
```
2080 404
```

**Leitura:** houve 2.080 tentativas de acesso a caminhos sensíveis, vindas de apenas 2 IPs (198.51.100.9 e 198.51.100.23) usando `python-requests` como user-agent — assinatura clássica de scanner automatizado de vulnerabilidades varrendo uma lista fixa de endpoints conhecidos. O servidor respondeu 404 em 100% dos casos, ou seja, o ataque não teve sucesso desta vez, mas a persistência e o volume mostram exposição real a bots de reconhecimento.


## Conclusao: minha primeira acao como operador de plantao
Se eu fosse o operador de plantão nesta madrugada, minha primeira ação seria avisar o time de backend sobre o /api/relatorio/gerar, porque ele está falhando muito: de cada 3 pessoas que tentam usar essa função, quase 1 recebe erro (34,8%). Isso é um problema real acontecendo agora, com usuários de verdade sendo afetados. Junto com isso, eu também bloquearia os 3 IPs que identificamos como bots (o que fazia buscas em excesso e os dois que ficaram testando /admin, .env, wp-login etc). Eles não são a prioridade número 1 porque, por enquanto, não causaram dano — mas continuar deixando passar é abrir espaço para um problema futuro, e bloquear é rápido e simples de fazer. Resumindo: primeiro aviso o erro que já está prejudicando gente de verdade, e enquanto isso resolvo o bloqueio dos IPs suspeitos, que é uma ação rápida e não custa nada fazer.