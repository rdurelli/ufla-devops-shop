# Isadora Melo 

- **GitHub:** @isadoramel0
- **Curso e periodo:** Ciencia da Computação, 8o periodo
- **Linguagem que voce domina melhor:** JavaScript
- **Ja usou Linux no dia a dia?** um pouco
- **Ja usou Docker?** nunca
- **O que voce espera desta disciplina:** espero sair com uma base sólida de infraestrutura e DevOps na prática, ou seja: entender containers, Kubernetes e Docker de verdade (não só de nome), ganhar mais confiança usando Linux no dia a dia, e conseguir aplicar isso em projetos reais e no mercado de trabalho.

## Diagnostico DORA do meu ultimo projeto

Pense no **ultimo projeto de software que voce entregou** — trabalho de
disciplina, projeto pessoal, estagio, TCC, o que for. Responda com honestidade.
Nao existe resposta errada aqui, e a nota **nao** depende de os numeros serem
bons.

- **Frequencia de implantacao:** quantas vezes aquele software foi para
  "producao" (entregue funcionando para alguem usar)?

  2 vezes

- **Lead time para mudancas:** quanto tempo passava, tipicamente, entre voce
  escrever um trecho de codigo e ele estar disponivel para o usuario?

  3 semanas

- **Tempo de restauracao:** quando algo quebrava na apresentacao ou em uso,
  quanto tempo levava para voltar a funcionar?

  3 dias

- **Taxa de falha em mudancas:** que proporcao das entregas quebrou algo que
  antes funcionava?

  50%

### Qual metrica era a pior, e por que

A pior métrica foi a taxa de falha em mudanças, com 50% das entregas quebrando algo que já funcionava. Isso acontecia principalmente pela falta de testes com usuários finais antes de ir para produção, as validações eram feitas majoritariamente do ponto de vista técnico, sem cobrir cenários reais de uso, então problemas que só apareciam na prática (comportamento inesperado, casos de uso não previstos, feedback de quem realmente usava o sistema) só eram descobertos depois do deploy. Isso também ajuda a explicar o tempo de restauração de 3 dias: sem um processo estruturado de validação prévia, corrigir um problema em produção dependia de identificar a causa, testar a correção e aguardar o próximo ciclo de deploy, em vez de pegar o erro antes de chegar ao usuário.

---

> Guarde este arquivo. Na **semana 15** voce vai reler o que escreveu hoje e
> refazer o mesmo diagnostico sobre a plataforma que tera construido. A
> diferenca entre os dois textos e, na pratica, o que voce aprendeu no semestre.

