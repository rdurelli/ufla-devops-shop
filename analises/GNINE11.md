# Autopsia: Cloudflare (02/07/2019)

**Autor:** Gabriel Jardim de Souza (@GNINE11)

**Fonte primaria:** https://blog.cloudflare.com/details-of-the-cloudflare-outage-on-july-2-2019/

**Data de acesso:** 30/08/2026

## 1. O que aconteceu
No dia 2 de julho de 2019, a Cloudflare publicou uma nova regra no firewall às 13:42 UTC. Essa regra tinha uma expressão regular que acabou consumindo quase toda a capacidade de processamento dos servidores. Poucos minutos depois, os sistemas de monitoramento começaram a identificar problemas e vários usuários passaram a receber erros ao acessar serviços que utilizavam a Cloudflare. A equipe então identificou que o problema estava no firewall e decidiu desativá-lo globalmente, fazendo o tráfego voltar ao normal às 14:09. Depois de encontrar e testar a correção, o firewall foi ativado novamente em toda a rede às 14:52.

## 2. Qual das Tres Vias falhou

A Via que mais falhou foi a do Fluxo. No relatório, a Cloudflare mostra que a nova regra do WAF foi enviada diretamente para toda a rede, sem passar primeiro por uma parte menor dos servidores. Com isso, o problema acabou afetando todos os usuários ao mesmo tempo.

## 3. Quais metricas DORA teriam denunciado antes
As métricas que poderiam ter mostrado o risco antes seriam o Change Failure Rate e o Mean Time to Restore. O Change Failure Rate mostraria se muitas alterações no WAF estavam causando problemas, enquanto o Mean Time to Restore mostraria se a recuperação após uma falha estava demorando mais do que o esperado. No relatório, a própria Cloudflare aponta que o processo de rollback era demorado.

## 4. Qual pratica do semestre teria evitado -- e em que semana
Uma prática que poderia ter evitado o problema seria usar uma estratégia de implantação em etapas, conteúdo da semana 8. Assim, a nova regra poderia ser testada em uma parte menor da rede antes de ser enviada para todos os servidores.

## 5. A cultura do relatorio: generativa ou patologica?
A cultura apresentada no relatório pode ser considerada generativa, pois a Cloudflare não tentou atribuir o incidente a uma única causa ou pessoa. Em vez disso, analisou as diferentes falhas que contribuíram para o problema e apresentou mudanças para evitar novos incidentes. Isso aparece no trecho: "Getting to a single root cause, while satisfying, may obscure the reality."