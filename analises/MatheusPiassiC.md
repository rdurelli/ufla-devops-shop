# Autópsia de Incidente Real: GitLab (2017)

## 1. O que aconteceu (em 5 linhas e sem jargão)
Durante uma manutenção para corrigir a sincronização de dados de um servidor secundário, um engenheiro executou acidentalmente um comando de exclusão de arquivos no servidor principal de produção. O comando apagou dados vitais e, ao tentar restaurar os dados, descobriu-se que todos os cinco sistemas de cópias de segurança (backups) automáticas haviam falhado nos dias anteriores. O sistema ficou fora do ar por cerca de 18 horas e aproximadamente 6 horas de dados de usuários foram perdidas permanentemente.

## 2. Qual das Três Vias falhou e por quê?
A **Segunda Via (Feedback)** falhou gravemente. O objetivo da Segunda Via é encurtar e amplificar os ciclos de retorno para detectar problemas o mais cedo possível e perto da origem. Os cinco mecanismos de backup estavam falhando há dias/semanas, mas não havia um pipeline ou sistema de monitoramento eficaz que enviasse alertas e amplificasse o sinal de falha para a equipe. Além disso, faltou teste de restauração automatizado (*game days* ou validação periódica dos backups) — o feedback de que o backup não funcionava só veio durante o desastre real em produção.

## 3. Quais métricas DORA teriam denunciado o problema antes?
* **Tempo médio de restauração:** A métrica estaria classificada no perfil Baixo (> 1 semana / 18 horas para contornar com perda de dados), denunciando a fragilidade da infraestrutura e a ausência de um mecanismo automatizado e testado de rollback/restauração rápida de desastres.
* **Taxa de falha em mudanças:** A execução de procedimentos de manutenção manuais operados diretamente em produção sem validação por código revelou uma taxa de falha catastrófica no processo de operação.

## 4. Prática da disciplina e semana do roadmap
* **Prática que teria evitado o dano:** Infraestrutura como Código (IaC) aliada ao controle de acessos automatizado, Implantação/Automação de Pipelines (CI/CD) e Monitoramento/Alertas automatizados. A manutenção de bancos de dados jamais deveria ser feita via comando manual executado via SSH por um humano em produção, mas sim parametrizada via scripts automatizados/testados.
* **Semana do roadmap:**
  * Semanas 2–3 (Linux, Bash e Administração de Sistemas): Entendimento de privilégios de execução, proteção contra comandos destrutivos (`rm -rf`) e automação via scripts.
  * Semana 14 (Provisionamento com Terraform): Aplicação de Infraestrutura como Código para eliminar procedimentos manuais em servidores.
  * Semanas 12–13 (Monitoramento e Alertas com Prometheus/Grafana): Criação de métricas e alertas automáticos para avisar quando jobs de backup falharem em segundo plano.

## 5. A cultura do relatório é generativa ou patológica?
A cultura demonstrada pelo GitLab após o incidente é estritamente Generativa.

> **Trecho do relatório/atuação pública que sustenta a resposta:**
*"Ao longo do processo de recuperação, o GitLab abriu uma transmissão ao vivo no YouTube e um documento compartilhado público no Google Docs onde qualquer pessoa podia acompanhar a investigação e os passos dos engenheiros em tempo real. O postmortem publicado no blog oficial detalhou cada falha do sistema sem citar ou punir o 'Engenheiro X', focando exclusivamente nas falhas dos processos e da infraestrutura."*

Em uma cultura patológica, o engenheiro teria sido demitido e o erro escondido para evitar prejuízo de imagem. O GitLab aplicou o postmortem sem culpados (*blameless postmortem*), buscando aprender com a falha e reestruturar o sistema, que é a marca registrada do pilar Culture (CALMS) q e de uma cultura generativa.