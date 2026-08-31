# Autopsia: GitLab 2017

# Autopsia: GitLab 2017 (31/01/2017)

**Autor:** Filipe Rezende Silva (@filipesilva07)

**Fonte primaria:** GitLab. *Postmortem of database outage of January 31*. 10 fev. 2017. https://about.gitlab.com/blog/postmortem-of-database-outage-of-january-31/

**Data de acesso:** 25/08/2026

## 1. O que aconteceu

Em 31 de janeiro de 2017, o GitLab.com começou a enfrentar problemas de carga no banco de dados e a replicação para o servidor secundário parou.
Durante uma tentativa de reconstruir a replicação, um engenheiro apagou por engano o diretório do banco primário em vez do secundário.
O erro foi interrompido rapidamente, mas cerca de 300 GB de dados já haviam sido removidos.
A equipe tentou recuperar os dados pelos backups, mas descobriu que os backups do PostgreSQL estavam falhando e que as notificações dessas falhas não estavam chegando.
O serviço levou cerca de 18 horas para ser restaurado usando um snapshot antigo, com perda de dados de produção de projetos, comentários e contas.

## 2. Qual das Tres Vias falhou

**Segunda Via — Feedback.**

A Segunda Via busca encurtar o ciclo de feedback e detectar problemas o mais cedo possível. No caso do GitLab, os backups estavam falhando porque o procedimento utilizava uma versão incompatível do PostgreSQL, mas a equipe não sabia disso porque as notificações por e-mail das falhas eram rejeitadas por problemas de DMARC.

Isso mostra uma falha de feedback: existia um mecanismo que deveria informar que os backups estavam com problemas, mas ele não produzia um sinal confiável. Se a falha tivesse sido detectada antes do incidente, a equipe poderia ter corrigido o procedimento de backup e testado a recuperação enquanto os dados ainda estavam disponíveis.

## 3. Quais metricas DORA teriam denunciado antes

A métrica mais claramente relacionada ao caso é o **Tempo de restauração**. Antes do incidente, a organização não tinha um processo de recuperação confiável e testado regularmente. Quando o banco foi perdido, a restauração levou mais de 18 horas, enquanto uma organização com recuperação madura deveria conseguir voltar ao funcionamento muito mais rapidamente.

O mecanismo é direto: uma restauração lenta ou difícil já indicaria uma fragilidade no processo de recuperação antes de um desastre. O próprio relatório mostra que não havia testes regulares do procedimento de backup porque não existia uma pessoa responsável por isso.

Não há evidência suficiente no relatório para afirmar que as outras três métricas DORA — frequência de implantação, lead time para mudanças e taxa de falha em mudanças — já estavam ruins antes do incidente. Por isso, a métrica mais defensável neste caso é o Tempo de restauração.

## 4. Qual pratica do semestre teria evitado -- e em que semana

**Métricas e alertas da Segunda Via — semana 8.**

Uma prática de monitoramento dos backups teria detectado automaticamente que o `pg_dump` estava falhando. O relatório mostra que os backups terminavam com erro, mas a equipe não recebia as notificações porque os e-mails eram rejeitados.

Com métricas e alertas confiáveis, a falha poderia ter sido identificada antes do incidente e o procedimento de backup poderia ter sido corrigido e testado. Essa prática teria criado exatamente o feedback que faltou no caso: um sinal automático de que a recuperação não estava realmente disponível.

## 5. A cultura do relatorio: generativa ou patologica?

**Generativa.**

O relatório demonstra uma postura de aprendizado e melhoria do sistema em vez de simplesmente culpar o engenheiro que cometeu o erro. O próprio GitLab reconhece que o problema estava relacionado aos procedimentos, à falta de automação, à ausência de testes de recuperação e à falta de monitoramento.

Um trecho que sustenta essa classificação é:

"An ideal environment is one in which you can make mistakes but easily and quickly recover from them with minimal to no impact."

Esse trecho mostra uma visão compatível com uma cultura generativa: o objetivo não é criar um ambiente em que ninguém erre, mas construir um sistema capaz de detectar erros, aprender com eles e se recuperar rapidamente. O relatório também transforma o incidente em ações concretas, como monitoramento dos backups, testes automatizados de recuperação e definição de responsabilidade pela durabilidade dos dados.