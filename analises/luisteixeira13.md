# Análise de Incidente: AWS S3 (2017)

## 1. O que aconteceu
Durante a depuração do faturamento do S3, um operador digitou incorretamente o comando de desligamento de servidores. A ferramenta removeu mais máquinas que o pretendido, derrubando os subsistemas centrais de índice (metadados) e alocação. Como esses serviços nunca haviam sido reiniciados na escala atual de US-EAST-1, o processo de verificação e recuperação demorou horas, deixando o S3 e serviços dependentes fora do ar por mais de 4 horas.

## 2. Qual das Três Vias falhou e por quê
A **Segunda Via (Feedback)** falhou porque não havia mecanismos rápidos de retorno, validação prévia de parâmetros ou travas de segurança (*guardrails*) para barrar um comando que violasse a capacidade mínima. Houve também falha na **Primeira Via (Fluxo)** pela ausência de remoção progressiva e contenção do raio de impacto (*blast radius*).

## 3. Quais métricas DORA teriam denunciado o problema antes
- **Tempo Médio de Restauração (MTTR):** Como o subsistema não era reiniciado completamente há anos em regiões grandes, o tempo real de recuperação era desconhecido e inaceitavelmente alto. Testes regulares de recuperação teriam denunciado a lentidão.
- **Taxa de Falha em Mudanças (CFR):** Procedimentos operacionais manuais sem validação estrita elevavam o risco de degradação imediata do ambiente a cada execução.

## 4. Qual prática deste semestre teria evitado o dano
- **Semanas 12-13 (Métricas, Alertas e SLOs / Chaos Controlado):** Injeção de falhas e validação de tempo de recuperação sob estresse.
- **Semanas 6-7 (Pipelines e Validação Automatizada):** Substituição de comandos manuais no terminal por rotinas automatizadas com regras estritas de verificação de parâmetros.

## 5. Cultura do relatório (Generativa vs. Patológica)
A postura é **Generativa** (tipologia de Westrum). O postmortem é *blameless*, tratando o erro humano como sintoma de falha no sistema/ferramentas e focando exclusivamente no aprendizado e correção estrutural.

> *"While removal of capacity is a key operational practice, in this instance, the tool used allowed too much capacity to be removed too quickly. We have modified this tool to remove capacity more slowly and added safeguards to prevent capacity from being removed when it will take any subsystem below its minimum required capacity level."*
