# Autopsia: Cloudflare (02/07/2019)

**Autor:** Guilherme Medeiros Gomes (@guilhermesemog)
**Fonte primaria:** https://blog.cloudflare.com/details-of-the-cloudflare-outage-on-july-2-2019/
**Data de acesso:** 01/09/2026

## 1. O que aconteceu

Às 13:42 UTC, uma nova regra do firewall da Cloudflare foi publicada automaticamente em toda a rede.
A regra continha uma expressão regular que exigia processamento excessivo e levou os servidores responsáveis pelo tráfego web a quase 100% de uso de CPU.
Três minutos depois, às 13:45, o primeiro alerta automático indicou uma falha, seguido por erros 502 e uma grande queda no tráfego.
Às 14:00 a equipe identificou o firewall como origem do problema e, às 14:07, conseguiu desativá-lo globalmente; às 14:09 o tráfego já havia voltado ao normal.
Depois de testar a correção de forma limitada, a Cloudflare reativou o firewall globalmente às 14:52.

## 2. Qual das Tres Vias falhou

**Fluxo.** O principal problema foi a forma como uma mudança percorria o caminho até a produção. A Cloudflare já possuía um processo progressivo para mudanças normais de software, passando por ambientes internos, pequenos grupos de clientes e servidores canário antes da implantação global. As regras do WAF, porém, eram uma exceção: seu procedimento permitia que uma alteração não emergencial fosse enviada diretamente para toda a rede.

Isso transformou uma regra defeituosa, que poderia ter afetado apenas uma pequena parcela do tráfego, em uma indisponibilidade mundial. A própria infraestrutura de distribuição da Cloudflare agravou o problema: o sistema Quicksilver conseguia propagar uma alteração para todas as máquinas em poucos segundos. Portanto, o erro da expressão regular foi o gatilho; a falha de Fluxo foi não existir uma etapa intermediária que limitasse o impacto antes da implantação global.

## 3. Quais metricas DORA teriam denunciado antes

A métrica mais útil seria o **Time to Restore Service (MTTR)**. O relatório mostra que o processo de rollback do WAF exigia executar o processo completo de build duas vezes, tornando a recuperação mais lenta do que deveria. Uma organização que acompanhasse o tempo necessário para recuperar alterações problemáticas poderia perceber que seu mecanismo de reversão tinha custo excessivo antes de enfrentar uma falha global.

A **Change Failure Rate** também deveria ser acompanhada especificamente para alterações das regras do WAF, mas o relatório não fornece evidência suficiente para afirmar que ela já era alta. Na verdade, a Cloudflare fazia dezenas de mudanças desse tipo por semana e não sofria uma interrupção global havia seis anos. Por isso, seria incorreto afirmar que todas as métricas DORA estavam ruins.

Deployment Frequency e Lead Time, isoladamente, pareciam bons: as alterações eram frequentes e chegavam à produção em segundos. O incidente mostra justamente que velocidade elevada não significa segurança quando o fluxo não contém mecanismos para limitar o impacto de uma mudança defeituosa.

## 4. Qual pratica do semestre teria evitado -- e em que semana

**Entrega e Implantação Contínuas — Semana 8.**

A prática que teria evitado que o incidente atingisse toda a rede seria o canary deployment, apresentado na Semana 8 do plano da disciplina, junto das estratégias de implantação rolling, blue-green e rollback planejado.

No caso da Cloudflare, a nova regra do WAF foi distribuída globalmente de uma só vez. Com canary deployment, ela teria sido aplicada primeiro a uma pequena parcela dos servidores. Como a regra fazia o uso de CPU subir rapidamente para níveis críticos, o problema provavelmente seria detectado nesse grupo antes da propagação para toda a infraestrutura.

Essa prática não impediria necessariamente a criação da regra defeituosa, mas criaria uma barreira entre o erro e seu impacto global, reduzindo o alcance da falha e permitindo interromper ou reverter a implantação antes que toda a rede fosse afetada.

## 5. A cultura do relatorio: generativa ou patologica?

O relatório demonstra uma cultura predominantemente **generativa**. Embora mencione que um engenheiro escreveu a expressão regular problemática, a análise não encerra a causa no erro individual. Ela identifica várias condições do sistema que permitiram que esse erro se tornasse uma interrupção global: ausência de teste de consumo de CPU, remoção anterior de uma proteção, falta de rollout progressivo, rollback lento e alertas inadequados.

Isso aparece claramente quando o relatório afirma: **“Getting to a single root cause, while satisfying, may obscure the reality.”**

A frase mostra que a organização evita procurar um único culpado e analisa como diferentes decisões técnicas e de processo se combinaram para produzir o incidente. Além disso, o relatório divulga publicamente as falhas e lista mudanças concretas no processo, como testes de desempenho, proteção contra consumo excessivo de CPU e implantação progressiva. Esse comportamento é compatível com uma cultura generativa, na qual falhas são usadas para melhorar o sistema em vez de apenas responsabilizar indivíduos.