# Análise — Incidente AWS S3

## 1. O que aconteceu

Em 28 de fevereiro de 2017, a equipe do Amazon S3 investigava um problema no sistema de cobrança. Um funcionário autorizado executou um comando de manutenção que deveria remover uma pequena quantidade de servidores. Um parâmetro foi digitado incorretamente e uma quantidade muito maior de servidores foi removida. Entre eles estavam servidores responsáveis por dois subsistemas críticos do S3: o sistema de índices, que mantém informações sobre os objetos armazenados, e o sistema de posicionamento, responsável pela alocação de armazenamento. Como consequência, o S3 ficou indisponível na região US-EAST-1 e outros serviços da AWS que dependiam dele também foram afetados. A recuperação completa do S3 ocorreu algumas horas depois.

## 2. Qual das Três Vias falhou?

A principal falha foi na Segunda Via. Essa via busca detectar problemas o mais cedo possível e próximo da origem, utilizando mecanismos de feedback, validações, testes e alertas.

O problema não foi simplesmente o funcionário ter digitado um parâmetro incorreto. O ponto mais importante é que o sistema permitiu que esse erro produzisse uma alteração muito maior do que a planejada. O comando não possuía uma proteção suficiente para impedir a remoção de capacidade abaixo do nível necessário para manter os subsistemas funcionando.

Isso mostra uma falha no feedback e nos mecanismos de segurança do processo: uma entrada incorreta deveria ter sido detectada e bloqueada antes de produzir impacto em produção.

Também houve um problema relacionado à Primeira Via, pois uma operação capaz de remover grande quantidade de capacidade tinha um potencial de impacto muito elevado. A ausência de um limite efetivo aumentou o tamanho do erro.

## 3. Quais métricas DORA teriam denunciado o problema?

Nenhuma, as métricas DORA são métricas do sistema de entrega e servem principalmente para identificar padrões de desempenho e estabilidade.

## 4. Qual prática deste semestre teria evitado o dano?

A prática de automação com validação e guardrails, trabalhada nas semanas 4–7.

No contexto de DevOps, o processo manual é um defeito e que a automação deve reduzir a possibilidade de erros repetitivos. Neste incidente, a AWS posteriormente modificou a ferramenta utilizada para impedir que uma entrada incorreta removesse capacidade abaixo do mínimo necessário.

Essa mudança é exatamente o tipo de automação preventiva que poderia ter evitado o incidente: em vez de depender apenas da atenção do operador, o próprio sistema deveria verificar se a operação era segura antes de executá-la.

O caso também reforça a importância de processos reproduzíveis, automatizados e verificáveis. O objetivo não é simplesmente executar uma tarefa mais rapidamente, mas criar mecanismos que impeçam erros humanos de se transformarem em falhas sistêmicas.

## 5. A cultura do relatório é generativa ou patológica?

Considero a cultura apresentada no relatório generativa. A AWS não atribui o incidente simplesmente ao funcionário que digitou o parâmetro incorretamente. O relatório procura explicar quais características do sistema permitiram que um erro humano causasse um impacto tão grande.

A própria AWS reconheceu que a ferramenta permitia remover capacidade em excesso e implementou guardrails para impedir que uma operação incorreta levasse um subsistema abaixo de sua capacidade mínima. Também foram identificadas melhorias para reduzir o tempo de recuperação e diminuir o impacto de futuras falhas.

Isso está alinhado com a cultura generativa apresentada na aula: a falha gera investigação e aprendizado, e a ação corretiva é aplicada no sistema. Em vez de perguntar apenas "quem errou?", a análise busca responder "por que o sistema permitiu que esse erro tivesse esse impacto?".