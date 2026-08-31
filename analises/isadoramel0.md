# Autopsia: AWS S3 Service Disruption (28/02/2017)

**Autor:** Isadora Gomes Melo Cunha (@isadoramel0)
**Fonte primaria:** https://aws.amazon.com/message/41926/
**Data de acesso:** 29/08/2026

## 1. O que aconteceu
Um funcionário autorizado da equipe do S3, seguindo um playbook já estabelecido, executou um comando para remover um pequeno número de servidores de um subsistema usado no processamento de faturamento. Um dos parâmetros do comando foi digitado errado, e um conjunto muito maior de servidores acabou removido, atingindo dois outros subsistemas críticos: o de índice (metadados de todos os objetos) e o de alocação de armazenamento. Sem esses dois, o S3 parou de atender GET, LIST, PUT e DELETE na região Norte da Virgínia, derrubando junto EC2, EBS, Lambda e o próprio console. Linha do tempo: início às 9h37 (PST); recuperação parcial às 12h26; subsistema de índice totalmente restaurado às 13h18; subsistema de alocação só voltou às 13h54 — quase 4h20 de interrupção total.

## 2. Qual das Tres Vias falhou
Fluxo. O comando que removeu os servidores foi executado manualmente, com um parâmetro digitado à mão, e não havia nenhuma barreira automática entre a intenção do operador (remover poucos servidores) e o efeito em produção (remover muitos mais). Não existia um limite de segurança impedindo que um subsistema caísse abaixo da capacidade mínima operacional, o fluxo ia direto do comando ao impacto, sem etapa de validação.

## 3. Quais metricas DORA teriam denunciado antes
O Tempo Médio de Restauração (MTTR) já era um risco invisível: o próprio relatório reconhece que os subsistemas de índice e de alocação não passavam por um reinício completo havia muitos anos nas regiões maiores, então ninguém tinha uma medição real de quanto tempo essa recuperação levaria em escala atual — e quando precisou, levou mais do que o esperado. A ausência de instrumentação sobre a taxa de falha de mudanças operacionais (não só deploys de código, mas comandos administrativos de risco) também escondia o problema: a ferramenta de remoção de capacidade era usada rotineiramente sem safeguards proporcionais ao dano que podia causar.

## 4. Qual pratica do semestre teria evitado -- e em que semana
Gates automáticos de validação antes da implantação de mudanças operacionais (Semana 8 — Entrega e Implantação Contínuas): se o processo de "entrega" desse comando de remoção de capacidade passasse por uma verificação automática travando qualquer execução que levasse um subsistema abaixo da capacidade mínima necessária o erro de digitação teria sido barrado antes de chegar à produção. O efeito ficaria restrito a poucos servidores, sem exigir o reinício completo de dois subsistemas inteiros.

## 5. A cultura do relatorio: generativa ou patologica?
Generativa. O relatório nunca atribui a causa ao funcionário que digitou o comando errado; ele é descrito apenas como alguém seguindo um playbook estabelecido. A explicação central está no sistema, não na pessoa: "the tool used allowed too much capacity to be removed too quickly". A AWS também expõe abertamente uma falha organizacional antiga não reiniciar esses subsistemas havia anos e lista mudanças concretas de engenharia como resposta, em vez de medidas disciplinares. Isso é típico de uma cultura Westrum generativa, que trata a falha como fonte de aprendizado e redesenho.