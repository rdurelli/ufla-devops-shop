# Parte A — Quem é você

- **GitHub:** @youserz
- **Curso e periodo:** Ciência da Computaçãoo, 8º periodo.
- **Linguagem que voce domina melhor:** C++.
- **Ja usou Linux no dia a dia?** Sim.
- **Ja usou Docker?** Um pouco.
- **O que voce espera desta disciplina:** Espero aprender os fundamentos, as práticas e as ferramentas de DevOps para aplicar essa cultura nos projetos da empresa em que trabalho.

# Parte B — Diagnóstico DORA do seu último projeto


``Frequência de implantação. 
Quantas vezes aquele software foi para “produção” (entregue funcionando para alguém usar)?``
- Meu último projeto está relacionado à Engenharia de Dados e utiliza a Arquitetura Medalhão. Nesse contexto, considerei como implantação em produção a entrega de uma camada do pipeline pronta e disponível para consumo.
A entrega de uma camada completa do pipeline acontecia, em média, uma vez a cada três meses

``Lead time para mudanças
Quanto tempo passava, tipicamente, entre você escrever um trecho de código e ele estar disponível para o usuário?``
- O tempo entre o início do desenvolvimento e a disponibilização da solução para os usuários era de aproximadamente três meses. Esse período incluía o desenvolvimento, a validação dos dados, a integração com outras partes do pipeline e a entrega da camada completa.

``Tempo de restauração
Quando algo quebrava na apresentação ou em uso, quanto tempo levava para voltar a funcionar?``
- Quando ocorria uma falha, o tempo médio para restaurar o funcionamento do pipeline era de um a dois dias, dependendo da complexidade do problema. Como não havia um mecanismo automatizado de rollback, a equipe precisava identificar a causa, corrigir o código e executar novamente as etapas afetadas.

``Taxa de falha em mudanças
Que proporção das entregas quebrou algo que antes funcionava?``
- Estimo que aproximadamente 10% das entregas causavam alguma falha ou regressão em funcionalidades que já estavam operando.


``Feche a Parte B com um parágrafo respondendo: qual dessas quatro métricas era a pior no seu
projeto, e o que exatamente causava isso?``
- A pior métrica era o tempo de restauração. O principal motivo era a ausência de artefatos versionados e de um mecanismo automatizado de rollback para os pipelines. Quando uma nova versão apresentava problemas, não era possível retornar rapidamente à versão anterior. A equipe precisava investigar a falha, aplicar uma correção e reexecutar manualmente o pipeline, o que aumentava o tempo de indisponibilidade. A criação de artefatos versionados, combinada com uma estratégia de implantação e rollback, reduziria significativamente esse tempo.