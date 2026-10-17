# Autopsia: Interrupcao do Amazon S3 na regiao US-EAST-1 (28/02/2017)
**Autor:** Caio Souza (@c-souzs)
**Fonte primaria:** https://aws.amazon.com/pt/message/41926/
**Data de acesso:** 31/08/2026

## 1. O que aconteceu
As 9h37 (horario PST), um funcionario autorizado tentou retirar poucos servidores para corrigir uma lentidao na cobranca do S3.
Um valor foi digitado errado e o sistema retirou servidores demais, interrompendo o acesso a arquivos e afetando outros servicos da Amazon.
O relatorio nao informa a hora exata em que a equipe detectou o problema nem quando o primeiro cliente percebeu; essa falta impede calcular o tempo de deteccao.
As 12h26, parte das operacoes voltou; as 13h18, leitura, listagem e exclusao ja funcionavam normalmente.
As 13h54, o envio de arquivos tambem foi restaurado e o S3 voltou a operar normalmente, 4 horas e 17 minutos depois do inicio.

## 2. Qual das Tres Vias falhou

A via que mais falhou foi o **Feedback**. O comando fazia uma alteracao muito grande, mas a ferramenta nao conferia se a quantidade informada deixaria os subsistemas abaixo da capacidade minima. Assim, o erro chegou ao ambiente em uso sem um aviso, bloqueio ou confirmacao proporcional ao risco. O proprio relatorio reconhece que a ferramenta permitia retirar capacidade demais e que, depois do incidente, ganhou protecoes. Isso mostra que faltava um retorno rapido do sistema antes de executar uma acao perigosa. Nao foi apenas uma pessoa que digitou um valor errado: o sistema aceitou esse valor e aplicou toda a mudanca de uma vez.

## 3. Quais metricas DORA teriam denunciado antes

Duas metricas DORA provavelmente mostrariam o risco: **taxa de falha em mudancas** e **tempo de restauracao do servico**. A primeira merece atencao porque uma operacao rotineira de manutencao conseguiu causar uma indisponibilidade de grandes proporcoes. Mesmo que erros assim fossem raros, acompanhar quantas mudancas operacionais exigiam correcao, reversao ou atendimento emergencial revelaria que as ferramentas aceitavam alteracoes perigosas sem protecao suficiente.

O tempo de restauracao daria um sinal ainda mais direto. A Amazon afirma que nao reiniciava completamente aqueles subsistemas nas regioes maiores havia muitos anos. Nesse periodo, o S3 cresceu bastante, mas o processo de reinicio e suas verificacoes nao acompanharam esse crescimento: a recuperacao demorou mais do que a equipe esperava. Testes periodicos de recuperacao teriam mostrado, antes do incidente, que restaurar o servico em grande escala levava horas. **Frequencia de implantacao** e **tempo entre uma mudanca e sua entrega** nao podem ser classificados como ruins com seguranca, pois o relatorio nao apresenta dados sobre eles.

## 4. Qual pratica do semestre teria evitado -- e em que semana

A pratica mais direta seria a **validacao automatica de entradas em scripts, da Semana 4**. Antes de executar a retirada, o script deveria calcular quantos servidores permaneceriam ativos e recusar qualquer valor que deixasse um subsistema abaixo do minimo seguro. Tambem poderia limitar a quantidade removida por vez, exigindo nova verificacao antes do lote seguinte. Essa barreira teria impedido que o numero digitado incorretamente virasse uma retirada em massa. Foi exatamente a correcao adotada depois: a ferramenta passou a remover capacidade mais devagar e a bloquear operacoes abaixo do limite minimo. Uma implantacao progressiva reduziria o impacto, mas a validacao seria melhor neste caso porque barraria o comando antes do dano.

## 5. A cultura do relatorio: generativa ou patologica?

O relatorio indica uma cultura **generativa**. Ele nao esconde o erro nem concentra a culpa no funcionario. Em vez disso, explica como a ferramenta, a arquitetura e o processo de recuperacao permitiram que um erro simples se tornasse uma falha extensa. O trecho **“the tool used allowed too much capacity to be removed too quickly”** coloca o foco no que o sistema permitiu, e nao em quem digitou o comando. A lista de acoes reforca essa postura: foram adicionadas protecoes, iniciou-se uma revisao de outras ferramentas, a divisao do servico em partes menores foi priorizada e o painel de status deixou de depender de uma unica regiao. Isso demonstra busca por aprendizado e mudancas no sistema para que o mesmo tipo de falha nao se repita.
