# Autópsia: GitLab.com Database Outage (31/01/2017)
**Autor:** João Victor de Morais Reis (@jvmoraireis18)  
**Fonte primária:** https://about.gitlab.com/blog/postmortem-of-database-outage-of-january-31/  
**Data de acesso:** 05/09/2026

## 1. O que aconteceu

Em 31/01/2017, um aumento na carga do banco fez a cópia de segurança entre os dois servidores parar de funcionar.  
Por volta das 23h, a equipe tentou reconstruir o servidor secundário, mas não percebeu que o processo de recuperação estava apenas aguardando.  
Às 23h30, um engenheiro apagou por engano a pasta do banco no servidor principal, removendo cerca de 300 GB de dados.  
As cópias de segurança também estavam falhando sem que a equipe soubesse, pois o processo usava uma versão incorreta do PostgreSQL e as notificações não chegavam.  
O GitLab.com ficou indisponível por cerca de 18 horas e dados criados entre 17h20 e 00h foram perdidos, incluindo aproximadamente 5.000 projetos, 5.000 comentários e 700 usuários.

## 2. Qual das Três Vias falhou

**Feedback — Segunda Via.**

A principal falha esteve na falta de retorno claro durante a recuperação. O comando `pg_basebackup` permanecia aguardando sem apresentar informações úteis, levando o engenheiro a interpretar incorretamente o seu comportamento. O próprio relatório afirma que esse funcionamento não estava claramente documentado nos procedimentos internos nem na documentação oficial. Além disso, posteriormente o GitLab identificou a necessidade de tornar mais evidente em qual servidor o operador estava trabalhando. Assim, a ausência de informações claras no momento da operação contribuiu diretamente para uma decisão incorreta.

## 3. Quais métricas DORA teriam denunciado antes

Entre as quatro métricas DORA, **Time to Restore Service (MTTR)** seria a mais diretamente relacionada ao problema, pois o incidente exigiu aproximadamente 18 horas para a restauração do serviço. Se esse tempo já fosse elevado em incidentes anteriores, ele indicaria uma dificuldade recorrente de recuperação e justificaria investimentos em procedimentos de restauração, testes de backup e automação.

A **Change Failure Rate** também poderia contribuir indiretamente, caso mudanças operacionais que provocassem indisponibilidade fossem contabilizadas. Entretanto, é importante destacar que as métricas DORA são indicadores de desempenho de entrega e recuperação, e não mecanismos específicos para detectar backups quebrados. Portanto, elas poderiam revelar uma fragilidade histórica na recuperação, mas não teriam identificado sozinhas que o `pg_dump` estava falhando. O relatório mostra que essa falha só foi descoberta durante o incidente.

## 4. Qual prática do semestre teria evitado — e em que semana

**Automação e teste sistemático do backup e da recuperação — Semana 4.**

A prática mais diretamente relacionada é a automação de scripts de backup, associada à execução periódica e à verificação de seu resultado. O relatório mostra que o backup com `pg_dump` falhava devido à incompatibilidade entre as versões do PostgreSQL, mas a equipe não era avisada porque as notificações por e-mail eram rejeitadas. Além disso, o procedimento não era testado regularmente porque não havia uma pessoa responsável por ele. A prática da Semana 4, que aborda automação, scripts de backup e execução periódica, poderia transformar essa atividade em um processo automatizado, verificável e recorrente, reduzindo a possibilidade de descobrir a falha somente durante uma emergência.

## 5. A cultura do relatório: generativa ou patológica?

**Generativa.**

O relatório trata o incidente como uma oportunidade de aprendizado e melhoria do sistema, em vez de concentrar a responsabilidade exclusivamente no engenheiro que executou o comando incorreto. A análise utiliza os **5 Whys** para investigar as causas do problema e propõe ações sistêmicas, como monitoramento dos backups, testes automatizados de recuperação, melhoria da documentação, múltiplos servidores secundários e definição de um responsável pela durabilidade dos dados.

Um trecho que evidencia essa postura é:

> “An ideal environment is one in which you can make mistakes but easily and quickly recover from them with minimal to no impact.”

A afirmação demonstra uma cultura generativa porque o objetivo não é simplesmente impedir que pessoas cometam erros, mas construir um ambiente no qual os erros possam ser identificados e recuperados rapidamente, reduzindo seu impacto. O relatório, portanto, prioriza aprendizado, melhoria dos processos e compartilhamento de responsabilidade em vez de punição individual.
