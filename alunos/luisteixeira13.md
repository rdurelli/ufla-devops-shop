
# Luis Felipe
- **GitHub:** @luisteixeira13
- **Curso e periodo:** Ciencia da Computacao, 2o periodo do mestrado
- **Linguagem que voce domina melhor:** Python
- **Ja usou Linux no dia a dia?** sim
- **Ja usou Docker?** sim
- **O que voce espera desta disciplina:** Utilizar DevOps para conectar meus conhecimentos e construir uma estrutura completa, trabalhando com containers, Kubernetes e suas ferramentas, de forma integrada em um projeto pratico.

## Parte B — Diagnóstico DORA

Para este diagnóstico, considerei como referência meu último projeto prático de DevOps, realizado durante um curso na Udemy, no qual trabalhei com Docker, Rancher e Kubernetes. Não era um ambiente de produção real, portanto alguns valores abaixo são estimativas baseadas na minha experiência durante o projeto.

| Métrica | Resposta |
|---|---|
| **Frequência de implantação** | Não foi uma métrica registrada. Durante o curso, realizei várias implantações e recriações do ambiente conforme avancei nas atividades. |
| **Lead time para mudanças** | Normalmente, algumas horas entre realizar uma alteração e conseguir disponibilizá-la funcionando no ambiente, principalmente por causa das configurações manuais. |
| **Tempo de restauração** | Geralmente dentro de 1 hora quando ocorria algum problema, pois era necessário identificar a causa e realizar novamente parte das configurações. |
| **Taxa de falha em mudanças** | Não foi medida formalmente. Pela minha percepção, aproximadamente 30% das alterações ou implantações exigiam alguma correção antes de funcionar como esperado. |

A métrica que considero pior no projeto foi o **tempo de restauração**. Tive problemas principalmente relacionados a versões das ferramentas e às configurações do ambiente. Em um dos casos, após uma alteração na máquina virtual, o endereço IP mudou e alguns componentes continuaram tentando acessar o endereço antigo. Como grande parte da configuração era realizada manualmente e ainda não tinha uma estrutura madura de automação, identificar e corrigir esses problemas podia levar algumas horas.

