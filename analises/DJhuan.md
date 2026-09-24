# Autópsia de um incidente real

## Jhuan Carlos Sabaini Dassie

---

### O ocorrido

A Cloudflare é uma empresa que se posiciona entre o cliente e o serviço que ele deseja acessar, de modo que o tráfego passa antes pelos seus servidores, o que permite filtrar o tráfego, acelerar respostas e adicionar regras de segurança. Por se tratar de uma empresa que cobre uma grandiosa parte da internet, qualquer queda é fatal. Em 24 de novembro de 2025, uma implantação que alterava a regra de acesso aos sistemas de bancos de dados fez com que buscas realizadas pelo sistema Bot Management retornassem informações duplicadas, fazendo com que os "arquivos de recursos" desses robôs dobrassem de tamanho. O arquivo, que era propagado pela rede de roteamento da empresa, era maior do que o esperado pelo software que essas máquinas utilizavam, gerando uma queda nos serviços da empresa.

### Qual das Três vias falhou?

A principal via a falhar foi a segunda: feedback. Por se tratar da movimentação de informações da direita para a esquerda, notamos uma quebra desse ciclo ao notar a falta de validação pelo sistema do "arquivo de recursos" antes da propagação. Outro ponto que corroborou para a falha é o diagnóstico inicialmente errôneo da empresa, que suspeitou de um ataque em massa de DDoS por conta da oscilação da rede, causado justamente por um sistema de reporte enganoso.

### Métricas DORA que denunciariam o problema antes

A métrica de "Taxa de falha em mudanças" seria essencial neste caso. Os erros surgiram em menos de meia hora após a implantação da nova funcionalidade, logo, uma correlação falha-mudança teria apontado imediatamente o problema e dado uma oportunidade de rollback antes que grande parte dela fosse afetada. Além disso, a métrica de "Frequência de implantação" seria essencial, uma vez que, com muitas implantações de uma só vez, ainda assim seria difícil notar qual delas foi a problemática.

### Qual prática da disciplina teria evitado o dano

Muito provavelmente as atividades da semana 3 e 13, que são, respectivamente, análise de log e painel e alerta. Ambos corroborariam para a vigilância, descoberta e diagnóstico do problema.

### A cultura do relatório é generativa ou patológica?

Generativa. O relatório é necessário justamente para diagnosticar e comunicar um problema, ou seja, a ideia aqui é justamente dar segurança psicológica para o delator, que ele saia do papel de culpado (patológico) e passe apenas a ser o mensageiro da informação, e que a culpa, na verdade, seja compartilhada. Esse é justamente o pular da cultura "responsabilidade compartilhada pelo resultado em produção; postmortem sem culpados; segurança psicológica para relatar erro". Olhando para o caso da Cloudflare, podemos estimar uma cultura de relatório generativa, visto que, [na postagem da empresa sobre o ocorrido](https://blog.cloudflare.com/pt-br/18-november-2025-outage/), o responsável pela publicação, Matthew Prince, deixa claro ao longo do texto que eles, como empresa, foram responsáveis pelo problema e também pela solução, como mostra o trecho: "Depois de suspeitarmos inicialmente que os sintomas que estávamos observando eram causados por um ataque de DDoS em hiperescala, identificamos corretamente o problema principal e conseguimos interromper a propagação do arquivo de recursos maior do que o esperado e substituí-lo por uma versão anterior do arquivo".

