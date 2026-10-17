# Autopsia: GitLab.com (31/01/2017)
**Autor:** Dominic Laercio Braz Dias (@DominicLaercio)
**Fonte primaria:** https://about.gitlab.com/blog/postmortem-of-database-outage-of-january-31/
**Data de acesso:** 30/08/2026

## 1. O que aconteceu

Às 23:00 UTC de 31/01/2017, a replicação do banco secundário falhou após ficar atrasada devido ao aumento da carga no banco.
Ao tentar recriar o secundário, um engenheiro executou acidentalmente um comando que apagou o diretório do servidor principal, contendo cerca de 300 GB de dados.
O erro foi percebido segundos depois, mas os cinco mecanismos de backup disponíveis não permitiram uma recuperação adequada.
A restauração precisou utilizar um snapshot manual do ambiente de staging, obtido às 17:20 UTC, resultando na perda de aproximadamente seis horas de dados de produção.
O serviço foi completamente restaurado em 01/02/2017, às 18:00 UTC, após cerca de 18 horas de recuperação.

## 2. Qual das Tres Vias falhou

**Feedback (Segunda Via).**
Embora tenha ocorrido uma falha de execução manual, o fator determinante para a gravidade do incidente foi a ausência de feedback confiável sobre os backups. O script automático de backup via `pg_dump` estava falhando silenciosamente devido à incompatibilidade entre as versões do PostgreSQL (9.2 e 9.6). As notificações de erro enviadas por e-mail também eram rejeitadas pelo servidor de e-mail devido à configuração de DMARC. Assim, a equipe não sabia que os backups estavam falhando até precisar utilizá-los durante o incidente.

## 3. Quais metricas DORA teriam denunciado antes

A métrica **Change Failure Rate (Taxa de Falhas em Mudanças)**.
Essa métrica mede a porcentagem de mudanças em produção (ou em rotinas operacionais) que geram falhas ou exigem intervenção. Antes do incidente, a rotina diária automatizada de backup via `pg_dump` estava falhando devido à incompatibilidade de versões entre o PostgreSQL 9.2 e 9.6. Se a organização monitorasse o indicador de sucesso/falha dessas rotinas de infraestrutura como parte de suas métricas DORA, o *Change Failure Rate* dos scripts de backup estaria em nível alto, revelando imediatamente que o sistema operava sem nenhuma rede de segurança antes mesmo do erro manual acontecer.

## 4. Qual pratica do semestre teria evitado e em que semana

A prática de **Automação de Testes de Infraestrutura e Validação Contínua de Backups**, abordada na **Semana 4 (Integração Contínua e Testes Automatizados)**, teria evitado parte importante do impacto do incidente.
Se houvesse uma rotina automatizada para restaurar periodicamente os backups em um ambiente temporário e validar sua integridade, a incompatibilidade do `pg_dump` teria sido detectada antes da necessidade de recuperação. Da mesma forma, a verificação automática das notificações teria revelado que os alertas de falha não estavam chegando à equipe. A automação e a validação dos procedimentos de recuperação também reduziriam a dependência de comandos manuais e diminuiriam o risco de executar uma operação destrutiva no servidor errado.

## 5. A cultura do relatorio: generativa ou patologica?

**Generativa.**
O relatório demonstra uma postura transparente e voltada ao aprendizado sistêmico, característica de uma cultura generativa segundo a tipologia de Westrum. Em vez de atribuir o incidente exclusivamente ao engenheiro que executou o comando incorreto, o relatório procura identificar quais procedimentos, mecanismos de recuperação e formas de monitoramento permitiram que um erro manual causasse uma perda tão grande. Isso fica evidente no seguinte trecho:

> "An ideal environment is one in which you can make mistakes but easily and quickly recover from them with minimal to no impact. This in turn requires you to be able to perform these procedures on a regular basis, and make it easy to test and roll back any changes."
