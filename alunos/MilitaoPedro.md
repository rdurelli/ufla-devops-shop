# <Seu Nome>

- **GitHub:** @MilitaoPedro
- **Curso e periodo:** Ciencia da Computacao, 8o periodo
- **Linguagem que voce domina melhor:** Java
- **Ja usou Linux no dia a dia?** sim
- **Ja usou Docker?** sim
- **O que voce espera desta disciplina:** Espero entender melhor o fluxo do código ao deploy e compreender os princípios/teoria por trás de DevOps

## Diagnostico DORA do meu ultimo projeto

Pense no **ultimo projeto de software que voce entregou** — trabalho de
disciplina, projeto pessoal, estagio, TCC, o que for. Responda com honestidade.
Nao existe resposta errada aqui, e a nota **nao** depende de os numeros serem
bons.

- **Frequencia de implantacao:** quantas vezes aquele software foi para
  "producao" (entregue funcionando para alguem usar)?
  O Software teve duas realeases até agora, então 2.

- **Lead time para mudancas:** quanto tempo passava, tipicamente, entre voce
  escrever um trecho de codigo e ele estar disponivel para o usuario?
  Por conta do tempo necessário para revisão de pares, de 4 à 6 dias. Porém, esse tempo se deu por serem MRs iniciais, logo são maiores.

- **Tempo de restauracao:** quando algo quebrava na apresentacao ou em uso,
  quanto tempo levava para voltar a funcionar?
  Cerca de 50 segundos, caso algo quebre em produção. Em sandbox esse tempo varia entre 1 minuto e 3 minutos.

- **Taxa de falha em mudancas:** que proporcao das entregas quebrou algo que
  antes funcionava?
  Foram raras as vezes que uma entrega quebrou e houve a necessidade de um rollback, nesse projeto especificamente nenhum dos dois commits quebrou em produção.

### Qual metrica era a pior, e por que

Acredito que o Lead Time para mudanças, mas acho que faz parte do trade-off da revisão de pares.

---

> Guarde este arquivo. Na **semana 15** voce vai reler o que escreveu hoje e
> refazer o mesmo diagnostico sobre a plataforma que tera construido. A
> diferenca entre os dois textos e, na pratica, o que voce aprendeu no semestre.
