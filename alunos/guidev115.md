# Guilherme Fabricio Brito da Rosa - 202120497

- **GitHub:** guidev115
- **Curso e periodo:** Ciencia da Computacao, 8o periodo
- **Linguagem que voce domina melhor:** PHP/Laravel
- **Ja usou Linux no dia a dia?** SIM - Direto, ainda mais no trabalho
- **Ja usou Docker?** Sim, e também Lando
- **O que voce espera desta disciplina:** Espero saber além dos comandos básicos e parte teórica sobre conterniziração, eu espero aprender a desenvolver algumas ferramentar pessoais de CI/CD. Além de claro, saber o basico de AWS e deployar algum projeto.

## Diagnostico DORA do meu ultimo projeto

Pense no **ultimo projeto de software que voce entregou** — Atualmente trabalho em um projeto da Covista (Adtalem) - https://www.covista.com/ - na qual temos que desenvolver vários features para várias faculdades/campus do grupo Adtalem.

- **Frequencia de implantacao:** quantas vezes aquele software foi para
  "producao" (entregue funcionando para alguem usar)?
  Deploy normalmente é feito semanalmente, toda quinta-feira, deploy de DEV em 15 dias, e Deploy em Prod em 15 dias.

- **Lead time para mudancas:** quanto tempo passava, tipicamente, entre voce
  escrever um trecho de codigo e ele estar disponivel para o usuario?
  Normalmente demora 15 dias até o deploy de PROD. 

- **Tempo de restauracao:** quando algo quebrava na apresentacao ou em uso,
  quanto tempo levava para voltar a funcionar?
  Nós evitamos esse problema por termos vários ambientes (DEV > STG > PROD) antes de fato do codigo novo entrar a acesso do cliente. Mas quando acontece, vira hotfix para ser corrigido em até 2 dias.

- **Taxa de falha em mudancas:** que proporcao das entregas quebrou algo que
  antes funcionava?
  Sempre foi uma margem de 22 para 1, isso olhando no ambiente de DEV/STG. Para ambiente de PROD, atualmente, nunca vi nesse momento de trabalho (estou há 7 meses).

### Qual metrica era a pior, e por que

Certamente é a taca de falha em mudanças. Apesar da margem ser grande para o ambiente DEV/STG, isso retorna para o desenvolvedor, e pode atrasar a sprint da equipe. E todo deploy que acontece, fazemos um smoke test para ver se não há algo quebrada nesses ambientes. Depois disso vai para UAT e é validado.

---

> Guarde este arquivo. Na **semana 15** voce vai reler o que escreveu hoje e
> refazer o mesmo diagnostico sobre a plataforma que tera construido. A
> diferenca entre os dois textos e, na pratica, o que voce aprendeu no semestre.