# Autopsia: CrowdStrike (19/07/2024)

**Autor:** Estevão Augusto da Fonseca Santos (@EstevaoAugusto)

**Fonte primaria:** https://www.crowdstrike.com/en-us/blog/falcon-content-update-preliminary-post-incident-report/

**Data de acesso:** 28/08/2026

## 1. O que aconteceu

Em 19 de julho de 2024, às 04:09 UTC, uma atualização automática de dados enviada pela empresa travou computadores Windows no mundo todo.

Devido a dados incorretos no arquivo baixado, os sistemas operacionais entraram em colapso e exibiram a tela azul de erro imediatamente.

O incidente afetou cerca de 8,5 milhões de máquinas, paralisando aeroportos, bancos, hospitais e serviços públicos globalmente.

Às 05:27 UTC (1 hora e 18 minutos depois), a empresa removeu o arquivo com defeito de seus servidores para impedir novas atualizações.

Contudo, a solução para os computadores já afetados exigiu acesso físico e correção manual direta em cada equipamento.

## 2. Qual das Tres Vias falhou

A Primeira Via (Fluxo), que estabelece a necessidade de um fluxo contínuo e seguro do código até a produção através de automação e barreiras de qualidade, falhou. No incidente, a CrowdStrike enviou a atualização de resposta rápida (Rapid Response Content) para todos os clientes globais simultaneamente, sem um pipeline de implantação gradual em fases (canary deployment), e confiou em uma ferramenta de validação automatizada (Content Validator) que continha um bug de lógica e aprovou o pacote corrompido sem bloqueá-lo.

## 3. Quais metricas DORA teriam denunciado antes

**Change Failure Rate (CFR - Taxa de Falhas em Mudanças):** O mecanismo de detecção seria o monitoramento em tempo real da taxa de erros por lote de distribuição. Assim que os primeiros computadores receberam a atualização e entraram em colapso, a CFR do lote atingiu 100%, o que deveria ter disparado uma interrupção automática para barrar o envio para o restante da frota global.

**Failed Deployment Recovery Time / MTTR (Tempo de Restauração de Serviço):** O mecanismo de detecção seria a medição do tempo necessário para reestabelecer o sistema após a falha. Como a falha em nível de kernel impedia a conexão com a rede para receber um novo arquivo de correção, o MTTR disparou criticamente, evidenciando a falta de um mecanismo de rollback automático local no próprio driver do sensor.

## 4. Qual pratica do semestre teria evitado -- e em que semana

* **Prática concreta:** **Canary Deployments (Implantação Gradual / Canário)** combinada com **Rollback Planejado**.
* **Semana do Roadmap:** **Semana 8** (Aula 7: Entrega e Implantação Contínuas)

Explicação: Se a prática de implantação gradual (canary) tivesse sido empregada, a atualização teria sido distribuída primeiro para um pequeno grupo de teste interno (canary group). A falha teria sido contida nas primeiras máquinas sem afetar a infraestrutura global.

## 5. A cultura do relatorio: generativa ou patologica?

Classificação: Generativa. O relatório demonstra uma cultura orientada a desempenho e aprendizado sistêmico (baseada no modelo de Westrum). O documento foca em total transparência pública, assume os problemas de arquitetura e validação, detalha as falhas de engenharia e estabelece ações corretivas concretas sem responsabilizar ou culpar indivíduos (blameless post-mortem).

Trecho citado literalmente:

    "This is CrowdStrike's preliminary Post Incident Review (PIR). We will be detailing our full investigation in the forthcoming Root Cause Analysis that will be released publicly."
