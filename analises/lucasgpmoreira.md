# Autopsia: GitLab.com (31/01/2017)

**Autor:** Lucas Gabriel Pereira Moreira (@lucasgpmoreira)
**Fonte primaria:** https://about.gitlab.com/blog/postmortem-of-database-outage-of-january-31/
**Data de acesso:** 16/09/2026

## 1. O que aconteceu

Em 31 de janeiro de 2017 o GitLab.com onde milhares de pessoas guardam e escrevem código, perdeu parte do seu banco de dados. Às 17:20 UTC um engenheiro copiou o banco de produção para o ambiente de teste, e por volta das 19:00 o site começou a ficar lento por causa de um volume anormal de acessos automatizados. Às 23:00 a cópia de segurança que acompanha o banco principal parou de conseguir acompanhar, e um engenheiro tentou refazer essa cópia à mão. Às 23:30 ele apagou o diretório de dados do servidor errado: percebeu e interrompeu em um ou dois segundos, mas cerca de 300 GB já tinham sido removidos. O site só voltou às 18:00 UTC do dia seguinte, mais de 18 horas depois, e as alterações feitas pelos usuários entre 17:20 e 00:00 foram perdidas de forma definitiva.

## 2. Qual das Tres Vias falhou

Falhou a Segunda Via, a do Feedback. O alarme existia, mas não chegava a ninguém. O backup diário feito com `pg_dump` vinha falhando havia tempo, porque rodava contra uma versão de PostgreSQL diferente da de produção, e o aviso dessa falha era enviado por e-mail.

O ciclo de retorno não estava quebrado na origem do problema, e sim no caminho entre o problema e a pessoa que poderia resolvê-lo. Vale reparar que o erro das 23:30 foi detectado em segundos pelo próprio autor. Detecção do incidente não era o gargalo. O que faltava era ter descoberto, semanas antes, que não havia rede de proteção embaixo.

## 3. Quais metricas DORA teriam denunciado antes

- Tempo de restauração: Antes de 31 de janeiro esse número não era ruim: ele não existia. Nenhuma restauração tinha sido ensaiada, então não havia medição nenhuma para consultar. O relatório diz por quê: "Because there was no ownership, as a result nobody was responsible for testing this procedure." Uma organização que não sabe dizer quanto tempo leva para voltar não tem um tempo de restauração alto, tem um tempo desconhecido, e o pior momento para descobrir esse valor é durante o incidente. As 18 horas não foram o problema. Foram a primeira medição.

- Taxa de falha em mudanças:, medida sobre operações de infraestrutura e não só sobre entregas de código. Recriar a réplica era tarefa manual: "Restoring this required manual work as this was not automated, nor was it documented properly." Procedimento manual, sem documentação, executado às 23:30 durante um incidente em andamento, tem probabilidade de erro que dá para estimar antes de qualquer acidente acontecer. O número que denunciava o risco era a proporção de operações de produção feitas à mão.

## 4. Qual pratica do semestre teria evitado

Monitoramento com alerta sobre métrica de backup, das semanas 12 e 13 do roadmap, quando entram Prometheus, Grafana e Loki.

O detalhe importante é que não bastaria um alerta de falha de backup, porque esse alerta já existia e morreu no filtro de e-mail. O que teria barrado o dano é uma métrica de idade do último backup válido, exportada para o Prometheus, com alerta disparando quando o valor ultrapassa 24 horas. A diferença está na direção da prova. O alerta por e-mail dependia de alguém conseguir enviar a notícia ruim, e bastou o DMARC para o canal sumir sem ninguém notar. A métrica de idade exige prova periódica de sucesso: se nada é reportado, o valor envelhece sozinho e o alerta toca do mesmo jeito. Com isso, o backup quebrado apareceria semanas antes do dia 31, e o comando errado das 23:30 teria custado minutos de indisponibilidade em vez de 18 horas e seis horas de dados dos usuários.

O complemento natural é o ensaio de restauração da semana 13, que troca "achamos que temos backup" por um número medido.

## 5. A cultura do relatorio: generativa ou patologica?

Generativa, e com folga.

O primeiro sinal é a informação ser buscada e exposta em vez de escondida, inclusive no pior momento. Enquanto o site estava fora do ar, a empresa manteve as anotações abertas ao público e transmitiu a recuperação: "In the spirit of transparency we kept track of progress and notes in a publicly visible Google document."

O segundo sinal é a linguagem. O relatório não nomeia o engenheiro que apagou o diretório, chama de "our engineer" e explica que o comportamento que o confundiu "was not clearly documented in our engineering runbooks". Mesmo o erro que originou o pico de carga é atribuído ao desenho do processo: "The current system used for responding to abuse reports makes it too easy to overlook the details of those reported."

Nos termos de Westrum, isso é informação buscada ativamente, responsabilidade tratada como estrutura compartilhada e falha que gera investigação em vez de caça às bruxas. Uma organização patológica teria publicado uma nota curta sobre "instabilidade momentânea" e demitido o engenheiro.
