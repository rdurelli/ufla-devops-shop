# Autopsia: AWS S3 Service Disruption (2017)
**Autor:** Luis Felipe Costa Teixeira (@luisteixeira13)
**Fonte primaria:** Summary of the Amazon S3 Service Disruption in the Northern Virginia (US-EAST-1) Region (AWS Postmortem)
**Data de acesso:** 27/08/2026

## 1. O que aconteceu
Às 09h37 PST, durante a manutenção da cobrança do S3, um operador digitou um comando incorreto que apagou servidores essenciais de catálogo e armazenamento em vez de poucas máquinas. A indisponibilidade foi imediata e detectada no mesmo minuto com a queda das APIs. Os subsistemas dependeram de reinicializações lentas de segurança, restabelecendo as operações de leitura às 12h26 PST e a normalização completa às 13h54 PST.

## 2. Qual das Tres Vias falhou -- e por que, com um fato do relatorio
A **Segunda Via (Feedback)** falhou. O fato determinante do relatório foi a ferramenta de manutenção aceitar um comando destrutivo e executar a remoção massiva sem qualquer mecanismo de validação prévia (*guardrails*), alerta imediato ou trava de segurança para impedir que a capacidade do cluster ficasse abaixo do limite operacional mínimo.

## 3. Quais metricas DORA teriam denunciado antes
- **Tempo Médio de Restauração (MTTR):** Como os subsistemas centrais de índice e alocação não eram reiniciados completamente em larga escala havia anos, a empresa desconhecia o tempo real de recuperação após um desligamento total. A métrica denunciaria que a restauração violava limites aceitáveis antes da falha ocorrer.
- **Taxa de Falha em Mudanças (CFR):** Procedimentos operacionais baseados em comandos manuais no terminal apresentavam alta vulnerabilidade latente a erros de digitação e ausência de barreiras de contenção.

## 4. Qual pratica do semestre teria evitado -- e em que semana
- **Semanas 12-13 (Monitoramento, Métricas, Alertas e Chaos Controlado):** Testes periódicos de injeção controlada de falhas (Chaos Engineering) para validar a recuperação de subsistemas sob estresse e definição de alertas/travas automáticas de capacidade mínima em tempo de execução.
- **Semanas 6-7 (Automação de Pipelines e Validação):** Substituição de intervenções manuais por rotinas automatizadas com validação estrita de parâmetros de entrada.

## 5. A cultura do relatorio: generativa ou patologica?
A cultura é **Generativa**. O documento segue a abordagem *blameless*, tratando o erro humano como gatilho e direcionando a causa raiz e as soluções para as limitações das ferramentas e processos de engenharia, sem punir o operador.

> *"While removal of capacity is a key operational practice, in this instance, the tool used allowed too much capacity to be removed too quickly. We have modified this tool to remove capacity more slowly and added safeguards to prevent capacity from being removed when it will take any subsystem below its minimum required capacity level."*
