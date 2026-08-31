# Autopsia: CLoudflare (2 de Julho de 2019)
**Autor:** João Pedro Dos Reis Moura (jotapemoura)
**Fonte primaria:** https://blog.cloudflare.com/details-of-the-cloudflare-outage-on-july-2-2019/
**Data de acesso:** 30/08/2026
## 1. O que aconteceu
Uma regra de segurança defeituosa derrubou os servidores da Cloudflare no mundo todo.
Às 13h42, a atualização entrou no ar e travou os processadores na hora, exibindo erro para os usuários.
Às 13h45, a equipe se reuniu em emergência e percebeu que não era um ataque de hackers.
Às 13h58, descobriram que a regra de segurança era a culpada e decidiram desligá-la.
Às 14h02, a ferramenta foi desativada e, às 14h09, a internet voltou a funcionar normalmente.
## 2. Qual das Tres Vias falhou
A Primeira Via (Fluxo) falhou. Essa via exige criar mecanismos de proteção para limitar o "raio de explosão" e impedir que falhas locais destruam todo o sistema. O relatório confirma essa quebra ao relatar que a empresa enviou a regra para a rede inteira de uma vez só: "On July 2, we deployed a new rule in our WAF Managed Rules that caused CPUs to become exhausted on every CPU core that handles HTTP/HTTPS traffic on the Cloudflare network worldwide."
## 3. Quais metricas DORA teriam denunciado antes
A Taxa de Falhas em Mudanças (Change Failure Rate) e o Tempo Médio de Recuperação (MTTR). O mecanismo de detecção seria a validação automatizada em ambiente de staging: ao submeter a nova regra a uma carga de testes sintéticos antes da aprovação da mudança, a exaustão de processamento seria registrada, reprovando o deploy imediatamente e impedindo que a taxa de falha atingisse a produção global.
## 4. Qual pratica do semestre teria evitado -- e em que semana
A prática de implantação contínua / canary, ensinada na Semana 8. Se a Cloudflare tivesse liberado a atualização para apenas 1% do tráfego ou em uma única região geográfica em vez do ambiente global, apenas uma fração mínima dos usuários seria afetada enquanto os monitores isolavam o erro.
## 5. A cultura do relatorio: generativa ou patologica?
A cultura é generativa (orientada ao aprendizado e voltada para a melhoria de processos, sem buscar culpados individuais). A empresa foca no erro da regra e do processo, assumindo a responsabilidade pública, como demonstra o trecho citado literalmente: "We know how much this hurt our customers. We're ashamed it happened. The CPU exhaustion was caused by a single WAF rule that contained a poorly written regular expression".
