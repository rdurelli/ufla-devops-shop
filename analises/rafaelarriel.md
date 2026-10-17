# Autopsia: Cloudflare Outage (02/07/2019)

**Autor:** Rafael Arriel (@rafaelarriel)
**Fonte primaria:** https://blog.cloudflare.com/details-of-the-cloudflare-outage-on-july-2-2019/
**Data de acesso:** 07/09/2026

## 1. O que aconteceu
Às 13:42 UTC, a Cloudflare publicou uma nova regra de segurança do WAF para todos os seus servidores.
A regra continha uma expressão que consumia CPU excessivamente, levando os servidores a quase 100% de uso e causando erros 502 globalmente.
Às 13:45, os primeiros alertas automáticos detectaram o problema, seguidos por outros alertas de queda de tráfego e falhas.
Às 14:07, a equipe conseguiu desligar o WAF globalmente e, às 14:09, o tráfego e o uso de CPU voltaram ao normal.
Às 14:52, após testes em uma pequena parte da rede, a equipe confirmou a correção e reativou o WAF globalmente.

## 2. Qual das Tres Vias falhou
Feedback -- a Segunda Via falhou porque o sistema não conseguiu fornecer feedback suficiente antes que a alteração atingisse toda a rede. O relatório afirma que a suíte de testes verificava se as regras bloqueavam ou permitiam corretamente as requisições, mas não verificava o consumo excessivo de CPU. Além disso, o primeiro alerta de queda global de tráfego demorou a disparar.
Isso é exatamente o problema descrito na Segunda Via da aula: o objetivo é detectar problemas "o mais cedo e o mais perto da origem possível". Nesse caso, o defeito poderia ter sido encontrado durante os testes, antes de chegar à produção, mas o feedback existente avaliava funcionalidade e não desempenho.

## 3. Quais metricas DORA teriam denunciado antes
As métricas mais relevantes seriam Taxa de falha em mudanças e Tempo de restauração.

A taxa de falha em mudanças mostraria o quanto as alterações estavam causando degradações que exigiam correção. O relatório informa que 476 mudanças foram realizadas no WAF Managed Rules em 60 dias, aproximadamente uma a cada três horas. Uma frequência tão alta torna especialmente importante acompanhar quantas dessas mudanças geram incidentes ou rollback.

O tempo de restauração também denunciaria uma fraqueza: embora o serviço tenha sido recuperado rapidamente após a desativação do WAF, a restauração completa do WAF só ocorreu às 14:52. O próprio relatório reconhece que o plano de rollback exigia executar o build completo duas vezes e era lento.
As outras duas métricas, frequência de implantação e lead time para mudanças, não podem ser classificadas como ruins com segurança a partir dos dados disponíveis. A aula também alerta que as quatro métricas devem ser analisadas em conjunto, e não isoladamente.

## 4. Qual pratica do semestre teria evitado -- e em que semana
Testes automatizados com análise de desempenho — Semana 8.

A prática mais diretamente relacionada ao incidente seria adicionar performance profiling das regras à suíte de testes, exatamente uma das ações que a própria Cloudflare identificou após o incidente. O problema é que os testes existentes verificavam se a regra funcionava, mas não se ela poderia consumir uma quantidade anormal de CPU.
No roadmap da disciplina, testes automatizados e análise estática aparecem nas semanas 6 e 8. Portanto, a prática da Semana 8 teria criado uma barreira diretamente contra o problema: a expressão regular seria executada sob medição de desempenho e poderia ser rejeitada antes de chegar à implantação global. Isso teria interrompido o fluxo do defeito ainda no processo de entrega, em vez de depender dos alertas de produção.

## 5. A cultura do relatorio: generativa ou patologica?
Generativa. O relatório demonstra uma postura de investigação do sistema em vez de procurar um único funcionário para responsabilizar. Ele afirma explicitamente que reduzir o incidente a uma expressão regular ruim esconderia a combinação de falhas que permitiu que o problema alcançasse toda a rede:

"the real story of how the Cloudflare service went down for 27 minutes is much more complex than 'a regular expression went bad'."
(“a verdadeira história de como o serviço da Cloudflare ficou fora do ar por 27 minutos é muito mais complexa do que ‘uma expressão regular deu errado’.”)

Isso se aproxima da definição de cultura generativa apresentada na aula: informação é buscada, responsabilidades são compartilhadas e a falha gera investigação e aprendizado. Em vez de encerrar a análise culpando quem escreveu a expressão, a Cloudflare identificou diversas barreiras ausentes ou inadequadas: proteção contra uso excessivo de CPU removida anteriormente, ausência de teste de consumo de CPU, rollout global sem etapas, rollback lento e dificuldades de acesso aos sistemas internos.

A própria resposta ao incidente reforça essa postura ao propor mudanças no sistema, como profiling de desempenho, novo mecanismo de expressões regulares e rollout progressivo. Isso caracteriza uma tentativa de transformar o incidente em melhoria estrutural, e não apenas em punição individual.