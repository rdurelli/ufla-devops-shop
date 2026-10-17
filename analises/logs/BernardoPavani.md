# Analise de access.log -- Bernardo Pavani (@BernardoPavani)
**Linhas analisadas:** 516866

## 1. Volume e falha
```bash
wc -l dados/access.log
# Saída: 516866 dados/access.log

awk '$9 >= 400 && $9 <= 499' dados/access.log | wc -l
# Saída: 6162

awk '$9 >= 500 && $9 <= 599' dados/access.log | wc -l
# Saída: 11749
```
**Leitura:** <Do total de 516.866, tivemos 6.162 erros do cliente, representando 1,19% do tráfego. As falhas do servidor somaram 11.749 ocorrências (2,27% do total), Justificando o relato de lentidão.>



## 2. Os 10 IPs mais frequentes
```bash
awk '{print $1}' dados/access.log | sort | uniq -c | sort -rn | head -n 10
# Saída (resumida):
#   88400 203.0.113.47
#    1788 192.0.2.245
#    1772 192.0.2.171
#    1771 192.0.2.81
#    1771 192.0.2.225
```
**Leitura:** <O IP 203.0.113.47 é suspeito. Além do volume (88.400 requisições), uma analise nas suas linhas revela que ele está requisitando o endpoint /api/busca de forma automatizada usando o user-agent curl/8.5.0. Trata-se de um bot executando scraping ou ddos, causando instabilidade (status 503) no servidor.>



## 3. O endpoint quebrado
```bash
awk '$9 == 500 {print $7}' dados/access.log | sort | uniq -c | sort -rn | head -n 5
# Saída (resumida):
#   3620 /api/relatorio/gerar
#    228 /
#    167 /api/produtos

awk '$7 == "/api/relator
# Saída: 10400
```

**Leitura:** <O caminho que mais gerou erro 500 foi /api/relatorio/gerar (3.620 falhas). Comparando com o seu total de 10400 requisições, concluímos que ele não quebra sempre, mas falha em 34,8% das vezes. Isso aponta para um problema de lentidão ou processamento no back-end no momento de gerar esse relatório.>



## 4. A hora do pico
```bash
awk '{print $4}' dados/access.log | cut -d: -f2 | sort | uniq -c | sort -rn
# Saída (resumida):
#  68535 23
#  43979 22
#  32529 15
#  32526 11
#  ...
#   1471 03
```

**Leitura:** <O pico absoluto ocorreu às 23h. Esse n. de acessos no final da noite foge do padrão e confirma que a sobrecarga do servidor foi causada pela intensa atividade identificada anteriormente, que operou majoritariamente neste horário.>



## 5. Alguém batendo na porta
```bash
awk '$7 ~ /(\/admin|\.env|\.git|wp-login|phpmyadmin)/' dados/access.log | wc -l
# Saída: 2080

awk '$7 ~ /(\/admin|\.env|\.git|wp-login|phpmyadmin)/ {print $1}' dados/access.log | sort | uniq | wc -l
# Saída: 2

awk '$7 ~ /(\/admin|\.env|\.git|wp-login|phpmyadmin)/ {print $9}' dados/access.log | sort | uniq -c
# Saída: 2080 404
```

**Leitura:** <Houve 2.080 tentativas de acesso a caminhos sensíveis, originadas de apenas 2 IPs distintos. O servidor respondeu de forma certa a todas com o código 404.>


## Conclusao: minha primeira acao como operador de plantao
<Minha primeira ação como operador de plantão
Bloquear imediatamente o IP 203.0.113.47 no servidor web. Os dados evidenciam que esse IP gerou 88.400 requisições no endpoint /api/busca, sendo a causa principal do esgotamento de recursos entre 22h e 23h.> 