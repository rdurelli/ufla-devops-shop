# ufla-devops-shop

Repositório da turma de **DevOps na Prática** — DCC / UFLA.

Prof. Dr. Rafael Serapilha Durelli · [rafael.durelli@ufla.br](mailto:rafael.durelli@ufla.br)

Este repositório é o **projeto fio condutor** da disciplina. Você faz um *fork*
dele na Atividade 0 e trabalha no seu fork durante as 15 semanas: a mesma
aplicação vai sendo containerizada, testada, empacotada, implantada, monitorada
e provisionada, semana após semana.

---

## Comece por aqui

1. Instale as ferramentas: **[docs/instalacao.md](docs/instalacao.md)**
   (Ubuntu/Debian, Fedora, macOS e Windows com WSL2).
2. Faça o *fork* deste repositório (botão **Fork**, canto superior direito).
3. Clone o **seu** fork e verifique a máquina:

   ```bash
   git clone git@github.com:<seu-usuario>/ufla-devops-shop.git
   cd ufla-devops-shop
   ./scripts/check-ambiente.sh
   ```

4. Siga o enunciado da **Atividade 0**, publicado no campus virtual.

---

## Estrutura

```
ufla-devops-shop/
├── docs/
│   └── instalacao.md          # roteiro de instalação por sistema operacional
├── scripts/
│   └── check-ambiente.sh      # verificador de ambiente (Atividade 0)
├── alunos/
│   └── _modelo.md             # modelo do seu arquivo de apresentação
└── .github/
    ├── pull_request_template.md
    └── workflows/             # verificação automática de cada atividade
```

A **aplicação** (API, banco, cache e front) entra no repositório no início do
Bloco 2, na Semana 5, junto com a Aula 4 — Containers I. Até lá o repositório
serve ao fluxo de entrega e à verificação de ambiente.

## `scripts/check-ambiente.sh`

Verifica ferramentas, versões mínimas, o daemon do Docker, a configuração do Git
e os recursos da máquina. Quando algo falta, imprime o comando de instalação
para o sistema detectado.

```bash
./scripts/check-ambiente.sh                      # relatório colorido
./scripts/check-ambiente.sh | tee ambiente.txt   # salva para anexar ao PR
```

Sai com código `0` se o ambiente estiver pronto e `1` se faltar algo
obrigatório. Versões mínimas: `git` 2.30, `docker` 24.0, `kubectl` 1.28,
`kind` 0.20, `helm` 3.12, `terraform` 1.5, Docker Compose v2.

O script também é material didático: na Semana 4 (shell script) abrimos este
arquivo em aula e discutimos as construções usadas nele.

---

## Como entregar

Toda atividade tem **duas etapas obrigatórias**. Faltando qualquer uma delas, a
atividade é considerada não entregue.

1. **Pull Request neste repositório**, com o trabalho feito na *branch*
   `atividade-NN` do seu fork.
2. **Link do Pull Request postado no campus virtual**, na tarefa correspondente.
   O horário desta postagem é o registro oficial da entrega.

O fluxo é sempre o mesmo:

```bash
git switch -c atividade-00                       # branch da atividade
git add alunos/<seu-usuario>.md ambiente.txt     # seus arquivos
git commit -m "feat: apresentacao e ambiente de <seu-usuario>"
git push -u origin atividade-00
```

Depois abra o Pull Request pelo GitHub, com o título no padrão
`Atividade 0 -- Seu Nome`.

### Verificação automática

Assim que o PR é aberto, o GitHub Actions roda sozinho e comenta o resultado em
cerca de um minuto. Se aparecer ✗ vermelho, leia o comentário, corrija, faça um
novo commit e dê `push` na mesma branch — o PR se atualiza sozinho. Você pode
repetir isso quantas vezes quiser antes do prazo.

A verificação automática **não é a nota**. Ela cobre o que a máquina consegue
julgar; a avaliação do professor complementa nos aspectos que ela não julga —
clareza, justificativa das decisões e qualidade da documentação.

### Atrasos e descarte

Atraso: desconto de 1,0 ponto por dia corrido, contado pelo horário da postagem
no campus virtual. Descarte: a menor nota entre as atividades do semestre é
descartada no cálculo final, sem necessidade de justificativa.

---

## Onde pedir ajuda

No **fórum da atividade**, no campus virtual. Pergunta pública gera resposta que
serve para a turma toda — e quase sempre alguém já passou pelo mesmo problema.

Ao relatar um erro, inclua:

1. o que você estava tentando fazer;
2. o comando exato que executou;
3. a mensagem de erro **completa**, copiada como texto (não como foto da tela);
4. o que você já tentou.

Esta é a mesma estrutura de um bom *issue* e de um bom *postmortem*.

---

## Uso de IA generativa

Permitido e incentivado. Em contrapartida, você deve ser capaz de explicar
qualquer linha entregue: a arguição final pergunta o *porquê* das decisões, não
a sintaxe.
