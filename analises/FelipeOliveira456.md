# Autopsia: GitLab.com (31/01/2017)

**Autor:** Felipe Geraldo de Oliveira (@FelipeOliveira456)
**Fonte primaria:** https://about.gitlab.com/blog/postmortem-of-database-outage-of-january-31/
**Data de acesso:** 05/09/2026

## 1. O que aconteceu

Em 31/01/2017, por volta das 23h30 UTC, um engenheiro apagou o diretorio de dados do banco principal do GitLab.com achando que estava no servidor secundario; o site caiu na hora. A linha do tempo: 17h20 UTC foi feito um snapshot para staging; 19h00 o banco ficou sobrecarregado; 23h00 a replicacao quebrou e o secundario foi zerado; 23h30 o comando errado atingiu o primario (~300 GB ja apagados). Os backups oficiais no S3 estavam vazios, entao a volta so ocorreu em 01/02 por volta das 18h00 UTC, com o snapshot de staging das 17h20. Resultado: cerca de 18 horas fora do ar e perda de ~6 horas de dados do banco (projetos, comentarios, contas); repositorios Git e wikis nao foram apagados.

## 2. Qual das Tres Vias falhou

**Feedback.** O gatilho foi um `rm` no host errado; a causa raiz e que o sistema de protecao nao avisou que ja estava morto. O `pg_dump` diario falhava porque rodava Postgres 9.2 contra um banco 9.6; o S3 ficou vazio. Havia e-mail de cron, mas o DMARC rejeitava as mensagens — "there was no indication of failure". Sem sinal de que o backup nao existia, ninguem corrigiu o procedimento ate precisar dele. A Via do Feedback e exatamente esse circuito: producao tem que devolver um sinal acionavel. Aqui o sinal foi descartado em silencio.

## 3. Quais metricas DORA teriam denunciado antes

Nao e o "tempo de restauracao de 18 horas" do incidente — isso descreve o estrago. O numero que ja denunciava o risco, se tivesse sido medido **antes**, era o **tempo de restauracao em exercicio**: um drill periodico de restore teria encontrado o bucket vazio e um "nao conseguimos restaurar". Equipes que acompanham MTTR de verdade nao esperam o desastre; elas cronometram o restore de proposito. A segunda metrica e a **taxa de falha em mudancas** do proprio job de backup: aquela "mudanca" recorrente (o cron de `pg_dump`) falhava em 100% das execucoes, so que ninguem olhava o resultado. Um painel de "backup last success" teria mostrado semanas (ou meses) sem ponto verde. Frequencia de implantacao e lead time de produto nao apontavam esse buraco; o buraco era operacional e ja estava aberto.

## 4. Qual pratica do semestre teria evitado -- e em que semana

**Semana 4 (Linux II: automacao, cron/systemd, script com `set -euo pipefail`, idempotencia).** O backup do GitLab era um cron que falhava e seguia a vida. Na Semana 4 o ponto nao e "saber o comando": e recusar job que termina sem checar saida, sem dono e sem prova de que funcionou. Um timer systemd (ou cron) que restaura o dump num ambiente descartavel e falha o job se o restore nao subir teria barrado exatamente o que o relatorio admite no 5 Whys: "Why was the backup procedure not tested on a regular basis? Because there was no ownership". Nao e Kubernetes nem canary — o primario foi apagado com a mao. O que faltava era automacao que **teste o restore**, nao so que dispare um dump.

## 5. A cultura do relatorio: generativa ou patologica?

**Generativa (Westrum).** O texto trata o `rm` como gatilho e gasta o resto do espaco no sistema: replicacao sem WAL archive, dump com versao errada, e-mail que nao chega, snapshot Azure desligado, ninguem dono do restore. Nao e "o funcionario falhou"; e "o sistema permitiu e depois nao tinha como voltar". Trecho literal: "An ideal environment is one in which you can make mistakes but easily and quickly recover from them with minimal to no impact." Eles ainda transmitiram a recuperacao no YouTube e publicaram o documento de progresso — comportamento de cultura que prioriza aprender no aberto, nao esconder o erro.
