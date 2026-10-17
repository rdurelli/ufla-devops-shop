# Autopsia: Cloudflare (02/07/2019)

**Autor:** José Acerbi Almeida Neto (@JoseJaan)
**Fonte primaria:** https://blog.cloudflare.com/details-of-the-cloudflare-outage-on-july-2-2019/
**Data de acesso:** 30/08/2026

## 1. O que aconteceu

Em 2 de julho de 2019 um engenheiro da Cloudflare publicou no filtro de segurança da empresa uma regra que continha uma instrução de busca de texto mal escrita.
Ao conferir cada requisição, a instrução fazia tentativas que se multiplicavam sozinhas, e em segundos os processadores da rede inteira, em mais de 180 cidades, ficaram 100% ocupados.
Como a Cloudflare fica na frente de milhões de sites, quem tentava abrir qualquer um deles recebia erro 502, e a empresa perdeu 80% do próprio tráfego.

Linha do tempo (UTC): 13h31 código aprovado, 13h37 testes automáticos verdes, 13h42 publicação (início), 13h45 primeiro alarme (detecção), 14h00 filtro identificado, 14h07 filtro desligado no mundo inteiro, 14h09 tráfego normal (restauração), num total de 27 minutos fora do ar.
Às 14h52, após testar a correção em uma só cidade e sem clientes pagantes, o filtro voltou globalmente.

## 2. Qual das Tres Vias falhou

**Fluxo.** A Primeira Via exige que a mudança percorra, do desenvolvimento à produção, um caminho capaz de conter o estrago, e era esse caminho que não existia para as regras do WAF. O relatório lista, entre as causas convergentes, que "The SOP allowed a non-emergency rule change to go globally into production without a staged rollout". A Cloudflare tinha o processo certo e sabia disso, para software normal o código passa por DOG (PoP só de funcionários), PIG (clientes não pagantes) e três PoPs Canary antes de ir a todos, num ciclo de "hours or days". O WAF ficou fora desse trilho de propósito ("by design, the WAF doesn't use this process because of the need to respond rapidly to threats"), ligado ao Quicksilver, que distribui uma mudança ao mundo inteiro com p99 de 2,29 segundos. Feedback funcionou (alarme em 3 minutos) e Aprendizado também (o próprio relatório). Só o Fluxo foi trocado por velocidade, sem nenhuma compensação de raio de alcance.

## 3. Quais metricas DORA teriam denunciado antes

**Tempo de restauração** e **taxa de falha em mudanças** já estavam ruins antes de 2 de julho, e ambas eram mensuráveis em qualquer terça-feira comum.

*Tempo de restauração.* O número anterior ao incidente não são os 27 minutos, é o tempo do procedimento de reversão descrito no próprio SOP, pois "The rollback plan required running the complete WAF build twice taking too long". Bastava cronometrar um rollback de ensaio para ver que desfazer uma regra custava dois builds completos, enquanto aplicá-la custava 2,29 segundos. Essa assimetria entre ida e volta é o número que denunciava o risco, qualquer erro ficaria em produção ordens de grandeza mais tempo do que levou para chegar lá. Na prática o rollback nem foi usado, e sim um interruptor de emergência ("global terminate").

*Taxa de falha em mudanças.* Ela precisa ser lida junto com a frequência de implantação, 476 change requests de WAF em 60 dias, uma a cada 3 horas, todas indo direto para 100% do planeta. O indicador antecedente é a fração dessas 476 que passou por DOG, PIG ou Canary, zero. Com raio de alcance sempre global, qualquer taxa de falha diferente de zero vira queda mundial. O número não previa qual regra quebraria, mas provava que a primeira a quebrar derrubaria tudo.

## 4. Qual pratica do semestre teria evitado -- e em que semana

**Implantação progressiva em Kubernetes (rolling update com canary e readiness probe), na Semana 10**, quando `kubectl` e `kind` entram no roadmap.

O que ela teria barrado é direto, com `maxUnavailable`/`maxSurge`, ou um canary recebendo 1% do tráfego, a regra nova entraria primeiro em um subconjunto de réplicas. A CPU dessas réplicas saturaria, a readiness probe pararia de responder e o próprio Kubernetes interromperia a propagação, com o resto da frota intacto. O prejuízo seria 1% de erro 502 em vez de 80% do tráfego mundial, e o alarme das 13h45 chegaria a um time que ainda tinha painel, Jira e Access no ar, sem depender do procedimento de bypass mal treinado que atrasou a resposta entre 14h02 e 14h07. É a correção que a Cloudflare adotou depois, "Changing the SOP to do staged rollouts of rules in the same manner used for other software at Cloudflare". Na **Semana 12**, o `helm rollback` cobre o segundo defeito, trocando dois builds por uma revisão já empacotada.

## 5. A cultura do relatorio: generativa ou patologica?

**Generativa.** O relatório recusa o culpado único e transforma o incidente em conhecimento compartilhado, marca da tipologia generativa de Westrum. A frase que sustenta isso: "As noted, we deploy dozens of new rules to the WAF every week, and we have numerous systems in place to prevent any negative impact of that deployment. So when things do go wrong, it's generally the unlikely convergence of multiple causes. Getting to a single root cause, while satisfying, may obscure the reality."

Duas evidências reforçam. Primeiro, a lista de "What went wrong" traz seis falhas de sistema (proteção de CPU removida numa refatoração, engine de regex sem garantia de complexidade, suite de testes cega para consumo de CPU, SOP sem rollout progressivo, rollback lento, alerta de queda de tráfego tardio) e nenhuma punição ao autor da expressão. Segundo, afirma que "Everything that occurred up to the point the rules were deployed was done 'correctly': a pull request was raised, it was approved, CI/CD built the code and tested it, a change request was submitted with an SOP detailing rollout and rollback, and the rollout was executed", ou seja, o processo foi seguido e ainda assim falhou. Numa cultura patológica essa frase seria impossível, ela absolve a pessoa e acusa o desenho do sistema.
