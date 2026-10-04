# Felipe Geraldo de Oliveira

- **GitHub:** @FelipeOliveira456
- **Curso e periodo:** Ciencia da Computacao, 8o periodo
- **Linguagem que voce domina melhor:** Java
- **Ja usou Linux no dia a dia?** sim
- **Ja usou Docker?** sim
- **O que voce espera desta disciplina:** Quero sair do "sobe na minha maquina" e passar a tratar entrega, rollback e observacao como parte do desenvolvimento. Espero praticar o fluxo git + PR o semestre inteiro e entender por que as metricas DORA mudam quando o processo deixa de ser manual.

## Diagnostico DORA do meu ultimo projeto

Pensei no ultimo software que entreguei de verdade para outra pessoa usar: um analisador estatico de codigo Java (analise de arquitetura / principios SOLID) feito para disciplina e para o meu TCC. "Producao" aqui era o professor, a banca e colegas rodando o jar/CLI na maquina deles — nao havia cluster nem URL publica.

- **Frequencia de implantacao:** o software foi para "producao" poucas vezes — essencialmente nas datas de entrega e na apresentacao. Entre um marco e outro eu acumulava commits locais e so gerava um artefato usavel quando o prazo apertava. Nao existia um ritmo semanal de release; era um empurrão por entrega.

- **Lead time para mudancas:** tipicamente dias, as vezes mais de uma semana. Eu escrevia um trecho (por exemplo, uma regra nova de deteccao), mas ele so ficava disponivel para quem ia usar depois que eu empacotava tudo de novo, testava na mao e mandava o zip/repo atualizado. Nao havia pipeline que publicasse a mudanca sozinha. O gargalo nao era escrever o codigo; era juntar, testar na mao e "entregar o pacote".

- **Tempo de restauracao:** quando quebrava na apresentacao ou num teste com o professor, o conserto era debug ao vivo ou um rollback mental ("volto o arquivo que eu tinha ontem"). Na pratica, de 15 minutos a algumas horas, dependendo de eu lembrar o que tinha mudado. Nao existia um botao de rollback nem uma versao anterior empacotada de proposito. Se o jar novo nao rodava, eu recompilava na hora.

- **Taxa de falha em mudancas:** alta perto das entregas. Uma proporcao grande das "releases" de ultima hora quebrava algo que antes funcionava — um teste que eu nao rodava, um caminho de arquivo hard-coded, uma dependencia que so existia na minha maquina. Longe do prazo a taxa era baixa porque eu quase nao entregava. Ou seja: eu falhava mais quando finalmente implantava.

### Qual metrica era a pior, e por que

A pior era o **lead time para mudancas**, e a causa nao era falta de commit: era a ausencia de um caminho curto entre "codigo no meu editor" e "outra pessoa consegue rodar". Cada entrega virava um evento (zip, instrucao oral, "clona de novo"), sem CI, sem artefato versionado de forma repetivel e sem checklist automatico. Isso alimentava as outras tres metricas: eu implantava pouco porque entregar doia; quando implantava, a taxa de falha subia porque o pacote nao tinha sido validado do mesmo jeito duas vezes; e o tempo de restauracao era adivinhar o diff na hora, porque nao havia uma versao anterior facil de recolocar no lugar. Em resumo, o projeto vivia no modo "heroico de vespera" — o contrario do que esta disciplina chama de fluxo.

---

> Guarde este arquivo. Na **semana 15** voce vai reler o que escreveu hoje e
> refazer o mesmo diagnostico sobre a plataforma que tera construido. A
> diferenca entre os dois textos e, na pratica, o que voce aprendeu no semestre.
