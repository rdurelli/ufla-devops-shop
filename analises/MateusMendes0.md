# Autopsia: Cloudflare Global Outage (02/07/2019)

**Autor:** Mateus Mendes (@MateusMendes0)
**Fonte primaria:** [Relatório oficial da Cloudflare](https://blog.cloudflare.com/details-of-the-cloudflare-outage-on-july-2-2019/)
**Data de acesso:** 30/08/2026

## 1. O que aconteceu

Às 13:42 UTC, a Cloudflare publicou uma nova regra de segurança destinada a identificar ataques em páginas web.
A regra continha uma expressão que exigia processamento excessivo e levou os servidores da empresa a praticamente 100% de uso de CPU em todo o mundo.
Às 13:45, os primeiros alertas automáticos indicaram problemas, seguidos por quedas de tráfego e erros 502 para usuários.
Às 14:07, a Cloudflare desativou globalmente o componente afetado e, às 14:09, o tráfego voltou aos níveis normais.
Após testar a correção em uma única localidade, a empresa reativou completamente o serviço às 14:52.

## 2. Qual das Tres Vias falhou

Feedback: A mudança percorreu o fluxo normal da Cloduflare, houve pull request, aprovação, integração contínua, testes e um plano formal de implantação e reversão. O problema foi que os mecanismos de feedback não avaliavam justamente o comportamento que causaria a falha. A própria Cloudflare afirma que sua suíte de testes não conseguia identificar consumo excessivo de CPU. Além disso, o alerta responsável por detectar a queda global de tráfego demorou mais do que deveria. Assim, o sistema fornecia feedback sobre erros funcionais da regra, mas não sobre seu impacto no desempenho da infraestrutura.

## 3. Quais metricas DORA teriam denunciado antes

As métricas mais relevantes seriam Change Failure Rate (CFR) e Time to Restore Service (MTTR).

O MTTR conseguiria revelaria fragilidade na recuperação, o relatório reconhece que o plano de rollback exigia executar o processo completo de construção do WAF duas vezes, tornando a reversão lenta. Durante o incidente, a equipe ainda encontrou dificuldades para acessar ferramentas internas e utilizar o mecanismo de emergência. Esses fatores indicavam que quando uma falha ocorresse restaurar o serviço poderia ser mais difícil do que o necessário.

## 4. Qual pratica do semestre teria evitado -- e em que semana

Pipeline de CI/CD com testes automatizados — Semanas 7–8.

Uma validação automatizada de desempenho no pipeline, executando as novas regras do WAF contra casos representativos e estabelecendo um limite aceitável de uso de CPU, teria identificado a expressão que causou a sobrecarga das CPUs antes que ela chegasse à produção. Nesse caso, o pipeline reprovaria o Pull Request ou impediria sua integração, barrando a mudança antes que pudesse ser distribuída globalmente.

## 5. A cultura do relatorio: generativa ou patologica?

Generativa. O postmortem não procura esconder o incidente nem atribuir a culpa exclusivamente ao engenheiro que escreveu a expressão problemática. Ao invés disso, descreve falhas técnicas e de processo, incluindo testes insuficientes, ausência de rollout gradual, rollback demorado, alertas lentos e dificuldades de acesso às ferramentas internas. Em seguida, apresenta ações concretas para corrigir esses problemas.

Essa postura aparece no seguinte trecho descrito no relatorio pela Cloudflare: **“transparently about a mistake we made, its impact and what we are doing about it.”**

Nesse trecho conseguimos perceber que as informações sobre o occorido estão sendo compartilhadas, a falha é investigada como oportunidade de aprendizado e a Cloudflare modifica seus processos após o incidente.