# Autopsia: Cloudflare (02/07/2019)

**Autor:** João Marcus Leite da Silva (@JoaoMarcus12)
**Fonte primaria:** Cloudflare — Details of the Cloudflare outage on July 2, 2019
**Data de acesso:** 30/08/2026

## 1. O que aconteceu

Em 02/07/2019, a Cloudflare publicou uma nova regra do Web Application Firewall (WAF) para detectar ataques XSS.
A regra continha uma expressão regular que causou um consumo excessivo de CPU nos servidores da Cloudflare.
Poucos minutos após a implantação, os serviços começaram a apresentar falhas em toda a rede.
A equipe identificou que a nova regra do WAF era a causa e desativou o componente globalmente para interromper o problema.
Após a correção da regra, o serviço foi restaurado e o WAF foi reativado posteriormente.

## 2. Qual das Tres Vias falhou

A principal falha foi na **Primeira Via — Fluxo**. O problema não foi apenas a existência de uma regra incorreta, mas a maneira como uma alteração conseguiu chegar rapidamente a toda a infraestrutura. A Cloudflare utilizava processos como DOG, PIG e Canary para implantações progressivas em outros componentes, mas o WAF possuía um processo diferente devido à necessidade de responder rapidamente a novas ameaças. Dessa forma, uma alteração problemática acabou sendo distribuída globalmente em pouco tempo, sem uma etapa intermediária capaz de limitar o impacto.

## 3. Quais metricas DORA teriam denunciado antes

A métrica mais relacionada ao risco apresentado pelo incidente seria a **taxa de falha em mudanças (Change Failure Rate)**. Uma alteração no WAF provocou uma indisponibilidade global, mostrando que mudanças desse componente podiam gerar impactos muito grandes quando chegavam à produção. Acompanhá-la permitiria identificar mudanças que resultassem em falhas e avaliar a necessidade de melhorar os mecanismos de validação antes da implantação.

A **frequência de implantação (Deployment Frequency)** também merece atenção. O relatório informa que ocorreram 476 mudanças no WAF em 60 dias. Uma frequência elevada de mudanças, principalmente em um componente crítico, aumenta a importância de possuir testes e mecanismos seguros de implantação. Sem essas proteções, uma alteração problemática pode chegar rapidamente a toda a infraestrutura.

O **tempo de restauração (MTTR)** também seria relevante para medir a capacidade de recuperação após uma falha. Embora essa métrica não impedisse diretamente o incidente, um tempo elevado mostraria que a organização tinha dificuldade para restaurar o serviço após uma mudança problemática.

## 4. Qual pratica do semestre teria evitado -- e em que semana

A prática que mais diretamente poderia ter evitado ou reduzido o impacto do incidente seria a **implantação progressiva**, apresentada no roadmap da disciplina na **semana 8**. Em vez de distribuir a nova regra para toda a rede imediatamente, a alteração poderia ser liberada inicialmente para uma pequena parcela da infraestrutura.

Caso o consumo de CPU aumentasse nessa primeira etapa, a implantação poderia ser interrompida antes que o problema atingisse toda a rede. Essa prática teria transformado uma falha potencialmente global em uma falha limitada a uma pequena parcela da infraestrutura.

Essa escolha é especialmente relevante porque a própria Cloudflare já utilizava mecanismos de implantação progressiva em outros componentes. O incidente demonstra que aplicar o mesmo princípio ao WAF poderia ter limitado significativamente o impacto.

## 5. A cultura do relatorio: generativa ou patologica?

Considero a cultura apresentada no relatório **generativa**. A Cloudflare não trata o incidente simplesmente como resultado de uma pessoa ter escrito uma expressão regular inadequada. O relatório procura explicar as condições técnicas e organizacionais que permitiram que a mudança chegasse à produção e causasse uma falha global.

Um trecho que demonstra essa abordagem é: **"the real story of how the Cloudflare service went down for 27 minutes is much more complex than 'a regular expression went bad'."** A afirmação mostra que a organização procurou entender o sistema como um todo, em vez de procurar apenas um culpado.

Além disso, o relatório apresenta ações corretivas relacionadas a testes, proteção contra consumo excessivo de CPU, implantação progressiva e recuperação. Isso demonstra uma preocupação em aprender com o incidente e modificar o sistema para reduzir a possibilidade de problemas semelhantes no futuro.
