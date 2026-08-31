# Autópsia de incidente — CrowdStrike (19/07/2024)

## 1. O que aconteceu

A CrowdStrike é uma empresa de cibersegurança que oferece serviços de proteção para ambientes de nuvem e aplicações nativas. O Falcon, produto da empresa, usa um componente que roda no kernel do Windows — o nível mais profundo de um sistema operacional, o que dá ao antivírus acesso total à máquina. Mas operar no kernel é arriscado, por um bom motivo: qualquer erro nesse nível pode travar completamente o sistema operacional e a máquina por inteiro. E foi exatamente isso que aconteceu neste incidente. A CrowdStrike enviou uma atualização de configuração (não uma atualização de software completa) que continha um defeito: o novo tipo de template definia 21 campos de entrada, mas o código só fornecia 20. Quando as máquinas carregaram esse arquivo, o componente no kernel tentou ler o 21º campo, que não existia, causando uma leitura fora dos limites da memória (*out-of-bounds read*) que travou o Windows. As máquinas entravam em loop de tela azul e não conseguiam nem inicializar. Isso significava que era impossível lançar uma correção remotamente, pois as máquinas não bootavam — era necessário entrar em modo de segurança e deletar o arquivo defeituoso à mão. Tudo isso aconteceu simultaneamente em cerca de 8,5 milhões de máquinas ao redor do mundo inteiro.

## 2. Qual das Três Vias falhou e por quê

No contexto das Três Vias do DevOps, houve falha em duas delas. Primeiro, uma falha na **Primeira Via (Fluxo)**: para um erro como o citado acima não ser detectado antes de chegar em produção, fica claro que o fluxo de entrega não tinha uma implantação progressiva — a atualização foi para todas as máquinas de uma vez, em vez de ser liberada em etapas (*canary/staged rollout*) que teriam limitado o dano a um grupo pequeno.

Mas o principal problema está na **Segunda Via (Feedback)**. O defeito atravessou múltiplas camadas de teste sem ser detectado, porque os testes usavam um critério "curinga" no 21º campo que nunca exercitava o caminho que quebrava — ou seja, o ciclo de feedback não pegou o problema perto da origem. Além disso, por se tratar de um erro que precisava ser ajustado manualmente em cada máquina ao redor do mundo, a resposta ao incidente levou dias a semanas para ser completamente solucionada. O feedback só chegou depois do desastre, e em escala global.

## 3. Quais métricas DORA teriam denunciado o problema antes

Com relação às quatro métricas DORA, este incidente foi um desastre quando falamos de **tempo de restauração (MTTR)**: a recuperação levou dias porque as máquinas nem inicializavam para receber a correção, o que expõe a ausência total de um rollback viável. A **taxa de falha em mudanças** também teria sinalizado o risco, mas o modelo de empurrar uma única atualização gigante para todos de uma vez mascara essa métrica. Se a empresa tivesse acompanhado o tempo de restauração e tomado mais cuidado com o deploy, o problema poderia ter sido minimizado a um grupo de testes.

## 4. Qual prática deste semestre teria evitado o dano

A prática que mais claramente teria evitado o dano é a **implantação progressiva (*staged rollout* / canary)**, ligada à Primeira Via e que veremos nas semanas de CI/CD e implantação automatizada (**semanas 6–7**). Com um rollout em anéis, a atualização defeituosa iria primeiro para uma fração pequena de máquinas; a tela azul apareceria nesse grupo reduzido e o rollout seria interrompido antes de atingir os 8,5 milhões. Vale notar que a própria CrowdStrike adotou exatamente essa prática como uma de suas mitigações — o relatório afirma que cada template instance deveria passar por um *staged rollout* com anéis sucessivos de implantação e verificações de aceitação. Como reforço, uma maior cobertura de **testes automatizados** (Segunda Via, **semanas 6 e 8**) teria pego o descompasso de campos ainda no pipeline.

## 5. A cultura do relatório é generativa ou patológica?

Segundo a tipologia de Westrum vista na aula, a cultura do relatório é generativa. A informação é buscada ativamente, a falha gera investigação e aprendizado, e o foco está no sistema, não em encontrar um culpado. O RCA detalha tecnicamente cada causa, assume as falhas de processo e lista mitigações concretas para cada uma, sem apontar o dedo para nenhuma pessoa.

O trecho que sustenta essa leitura é a conclusão sobre a causa raiz, que enquadra o incidente como uma falha de sistema, e não humana:

> "In summary, it was the confluence of these issues that resulted in a system crash: the mismatch between the 21 inputs validated by the Content Validator versus the 20 provided to the Content Interpreter, the latent out-of-bounds read issue in the Content Interpreter, and the lack of a specific test for non-wildcard matching criteria in the 21st field."

Ao descrever o desastre como uma *confluência* de falhas do próprio sistema de validação, teste e interpretação de conteúdo — e não como o erro de um indivíduo —, o relatório assume a postura característica de uma cultura generativa: a pergunta que ele responde é "que parte do sistema permitiu isso?".
