# Lucas Gabriel Pereira Moreira

- **GitHub:** @lucasgpmoreira
- **Curso e período:** Mestrado em Ciência da Computação
- **Linguagem que você domina melhor:** JavaScript/TypeScript
- **Já usou Linux no dia a dia?** Sim
- **Já usou Docker?** Um pouco
- **O que você espera desta disciplina:** Aprender Docker com mais profundidade. Já usei containers no trabalho, mas sempre em cima de uma configuração que outra pessoa montou, rodando comando sem entender direito o que acontecia por baixo. Quero terminar a disciplina sabendo explicar o que cada parte faz, e não só repetir passo que funciona.

## Diagnóstico DORA do meu último projeto

Uso como referência o SIDAGRO, sistema em que trabalho. A estrutura de entrega é boa: tem pipeline de CI/CD, testes automatizados e três ambientes separados (desenvolvimento, homologação e produção).

- **Frequência de implantação:** Poucas vezes. O sistema não tem usuário até hoje. O que a gente chamava de produção nunca recebeu ninguém, porque faltava uma aprovação de terceiros que não veio.

- **Lead time para mudanças:** Minutos até homologação. Eu escrevia o código, abria o merge request, a pipeline rodava os testes e publicava. Até o usuário não dá para medir, porque não chegou.

- **Tempo de restauração:** Pouco. Era corrigir e deixar a pipeline rodar. O caminho de volta era o mesmo da ida, sem mexer no servidor na mão.

- **Taxa de falha em mudanças:** Uns 1 em 10. Quase tudo que quebrava era pego ainda em desenvolvimento ou homologação.

### Qual métrica era a pior, e por quê

A frequência de implantação, e o problema não era técnico. A pipeline entrega em minutos. O que travava era a decisão de liberar o sistema, que não dependia do time. Sobrou uma esteira bem feita sem nada passando por ela. As outras três métricas acabam parecendo boas por causa disso, porque nunca foram testadas por usuário de verdade. Não tem ninguém para notar uma queda nem uso real para expor o que os testes não pegam. Não quebrar em produção é fácil quando produção está vazia.
