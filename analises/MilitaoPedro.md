# Autopsia: Apagão global da Cloudflare (2 de julho de 2019)

**Autor:** Pedro Militao Mello Reis (@MilitaoPedro)
**Fonte primaria:** https://blog.cloudflare.com/details-of-the-cloudflare-outage-on-july-2-2019/
**Data de acesso:** 07/09/2026

## 1. O que aconteceu

A Cloudflare é o "porteiro" de milhões de sites: o tráfego passa por ela antes de chegar ao dono do site. Em 2/7/2019, às 13:42 (UTC), um funcionário publicou no mundo inteiro, de uma só vez, uma atualização de rotina (uma regra nova para detectar ataques). A regra era defeituosa, para certos textos ela "voltava atrás" (backtracking) e recomeçava o cálculo milhões de vezes, ocupando o computador por completo, que parava de responder. Por cerca de 27 minutos, visitar qualquer site protegido devolvia erro 502 (a página não abre); a queda foi percebida 3 minutos depois, quando os alarmes soaram e ~80% do tráfego sumiu. Às 14:07 a regra foi desligada no mundo, às 14:09 o tráfego voltou ao normal e às 14:52 a proteção foi religada, após testes. Não houve ataque nem perda de dados, foi uma mudança interna malfeita.

## 2. Qual das Tres Vias falhou

**Fluxo** (a Primeira Via). A Primeira Via exige que mudanças atravessem o sistema em lotes pequenos e por estágios que barram defeitos antes que alcancem todo mundo, e é assim que a própria Cloudflare entrega software, na escada DOG → PIG → Canários → mundo. A regra que derrubou a rede pulou essa escada: regras de WAF são distribuídas pelo Quicksilver, que leva uma mudança ao mundo em segundos, e o procedimento padrão permitia deploy global sem rollout em estágios. O fato do relatório: "the SOP allowed a non-emergency rule change to go globally into production without a staged rollout". Vale notar que o feedback funcionou (o primeiro alarme soou três minutos após o deploy), o que falhou foi o fluxo, que deixou a mudança ir direto da CI para 100% da rede, sem nenhum portão entre "testada" e "testada no mundo todo".

## 3. Quais metricas DORA teriam denunciado antes

A **Taxa de falha em mudanças** (Change Failure Rate): seria a denúncia, e o mecanismo que a inflava já rodava antes do incidente: 476 mudanças de regras em 60 dias (uma a cada ~3 horas), empurradas ao mundo sem estágio e validadas por uma suíte que, diz o relatório, não media consumo de CPU, exatamente o tipo de defeito que derrubou a rede. Nesse fluxo, uma fração relevante das implantações já exigia remediação de emergência, o que colocaria a taxa bem acima do teto "elite" de 15% do DORA: o número já dizia que o pipeline de mudanças era inseguro, e 2/7 foi só a primeira falha com alcance global. A métrica vinha mascarada para baixo, porque o teste não enxergava o estouro. As outras três pareciam ótimas pela razão errada, lead time "em segundos" e frequência altíssima eram conquistados removendo a rede de segurança, não melhorando o fluxo.

## 4. Qual pratica do semestre teria evitado -- e em que semana

**GitOps via ArgoCD — Semana 12** do roadmap: "é implantada por GitOps via ArgoCD: um git push passa a ser a única forma de mudar produção". O apagão só foi possível porque existia um caminho para alterar produção fora do fluxo normal, uma regra publicada direto no mundo em segundos, por atalho administrativo. GitOps elimina esse caminho: a mudança viraria um commit revisado e testado na esteira, e o ArgoCD a sincronizaria de forma controlada e observável, em etapas, em vez de um push global instantâneo. Além disso, o rollback, que no relatório exigia reconstruir o WAF duas vezes e atrasou a recuperação, viraria reverter um commit e ressincronizar, em segundos. Uma mudança ruim teria sido contida e revertida antes de tocar 100% dos clientes.

## 5. A cultura do relatorio: generativa ou patologica?

**Generativa.** Pela tipologia de Westrum, este é um relatório de cultura generativa: a falha é tratada como defeito do sistema, não da pessoa. A informação flui (o documento é público e detalhado), e ninguém é apontado como culpado, o engenheiro que escreveu a regex aparece apenas como "an engineer". A prova está na escolha de vocabulário, que lista causas sistêmicas em vez de culpar o operador, por exemplo quando diz que a proteção contra CPU "was removed by mistake" num refactor. Trecho literal que sustenta a classificação: "Here are the multiple vulnerabilities that converged to get to the point where Cloudflare’s service for HTTP/HTTPS went offline." Numa cultura patológica o texto culparia o funcionário e enterraria o caso, aqui a publicação aberta e sem culpados.
