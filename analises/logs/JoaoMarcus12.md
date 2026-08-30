# Analise de access.log -- Joao Marcus (@JoaoMarcus12)

**Linhas analisadas:** 516866

## 1. Volume e falha
```bash
echo "Total: $(wc -l < dados/access.log)"
echo "4xx: $(awk '$9 ~ /^4/ {print $9}' dados/access.log | wc -l)"
echo "5xx: $(awk '$9 ~ /^5/ {print $9}' dados/access.log | wc -l)"
```
```
Total: 516866
4xx: 6162
5xx: 11749
```
**Leitura:** O log possui 516.866 requisições. As falhas 4xx representam aproximadamente 1,19% do total, enquanto as falhas 5xx são mais significativas, representando 2,27% do volume total.

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
**Leitura:** O IP `203.0.113.47` é extremamente suspeito, com 88.400 requisições. A análise do User-Agent (`grep "203.0.113.47" dados/access.log | awk -F'"' '{print $6}' | sort | uniq -c`) revela que todas as requisições usam `curl/8.5.0`, e os caminhos mais acessados são endpoints de busca (`/api/busca?q=...`), caracterizando um comportamento de scraping automatizado.

## 3. O endpoint quebrado
```bash
awk '$9 == "500" {print $7}' dados/access.log | sort | uniq -c | sort -rn | head -1
```
```
   3620 /api/relatorio/gerar
```
**Leitura:** O caminho `/api/relatorio/gerar` é o que mais causa erros 500. Comparando com o total de requisições para este endpoint (`grep -c "/api/relatorio/gerar" dados/access.log` resultou em 10.400), a taxa de erro é de aproximadamente 34,8%, indicando uma instabilidade crítica neste recurso.

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
**Leitura:** O tráfego cresce consistentemente ao longo do dia, atingindo seu pico máximo às 23h com 68.535 requisições.

## 5. Alguém batendo na porta
```bash
# Quantidade total
grep -E '/admin|\.env|\.git|wp-login|/phpmyadmin' dados/access.log | wc -l
# IPs distintos
grep -E '/admin|\.env|\.git|wp-login|/phpmyadmin' dados/access.log | awk '{print $1}' | sort | uniq | wc -l
# Respostas do servidor
grep -E '/admin|\.env|\.git|wp-login|/phpmyadmin' dados/access.log | awk '{print $9}' | sort | uniq -c
```
```
2080
2
   2080 404
```
**Leitura:** Houve 2.080 tentativas de acesso a caminhos sensíveis partindo de apenas 2 IPs distintos. O servidor respondeu corretamente com erro 404 para todas as tentativas, indicando que os recursos não estão expostos.

## Conclusao: minha primeira acao como operador de plantao
Minha primeira ação seria bloquear o IP `203.0.113.47` via firewall ou WAF. Este IP é responsável por quase 17% de todo o tráfego do servidor, utilizando um cliente `curl` para realizar scraping intensivo de endpoints de busca, especialmente nas horas de pico (22h e 23h), o que provavelmente está degradando a performance para usuários legítimos. Após a mitigação do bot, escalaria o problema do endpoint `/api/relatorio/gerar` para a equipe de desenvolvimento, dado a sua taxa de falha de ~35%.
