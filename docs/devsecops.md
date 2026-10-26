# Trabalho Prático — Pipeline DevSecOps

O workflow `.github/workflows/devsecops.yml` executa em Pull Requests para
`main` e em pushes para `main`. A publicação da imagem só acontece depois que
testes, Gitleaks, SonarCloud, Trivy e SBOM terminam com sucesso.

## Verificações

- **Gitleaks** analisa o histórico completo do repositório e falha quando
  encontra um possível segredo.
- **SonarCloud** executa análise SAST usando cobertura dos testes Python e
  bloqueia a execução quando o Quality Gate falha.
- **Trivy** gera relatórios de filesystem e imagem. O workflow bloqueia
  vulnerabilidades `HIGH` e `CRITICAL` com correção disponível (`--ignore-unfixed`);
  `LOW` e `MEDIUM` permanecem nos artifacts `trivy-reports`.
- **Syft** gera `ufla-shop-sbom.cdx.json` em formato CycloneDX e publica o SBOM
  como artifact da execução.
- **GHCR** recebe somente a imagem versionada após todos os gates obrigatórios.

## Configuração manual no GitHub

1. Criar o projeto `guilhermesemog_ufla-devops-shop` no SonarCloud, na
   organização `guilhermesemog`.
2. Em **Administration > Analysis Method**, desativar **Automatic Analysis**.
  O workflow executa a análise por CI; os dois métodos não podem ficar ativos
  ao mesmo tempo.
3. Criar um token do SonarCloud e cadastrá-lo no repositório como secret
   `SONAR_TOKEN`.
4. Configurar no SonarCloud o Quality Gate para código novo, incluindo ausência
   de vulnerabilidades e Security Hotspots revisados.
5. Em **Settings > Rules > Rulesets** ou **Branches**, proteger `main` e exigir
   os checks `Gitleaks`, `SonarCloud quality gate`, `Trivy vulnerability scans`
   e `Tests and image build` antes do merge.

O token não deve ser colocado em arquivos, commits ou logs.

## Evidências exigidas

As execuções do GitHub Actions devem fornecer:

- um Pull Request de demonstração com o check Trivy falhando para uma
  dependência vulnerável corrigível, sem publicar essa imagem;
- o mesmo Pull Request corrigido, com os checks aprovados;
- o artifact `ufla-shop-sbom.cdx.json` e os artifacts `trivy-reports`;
- a página do Pull Request bloqueado e o trecho do relatório da vulnerabilidade;
- a execução aprovada após a correção.

Para a demonstração, use uma branch temporária e altere apenas uma dependência
para uma versão com CVE conhecida. Abra o Pull Request, registre a falha e
reverta a dependência para uma versão corrigida antes de qualquer merge ou
publicação.

## Checklist final e links da entrega

Substitua cada marcador entre colchetes pelos links reais do GitHub antes de
entregar. Não use caminhos locais do Windows, como `C:\Users\...`.

```text
Repositório:
https://github.com/guilhermesemog/ufla-devops-shop/

Pull Request principal do trabalho:
https://github.com/guilhermesemog/ufla-devops-shop/pull/9

Pull Request bloqueado pela vulnerabilidade:
https://github.com/guilhermesemog/ufla-devops-shop/actions/runs/40418087766

Pull Request ou execução após a correção:
https://github.com/guilhermesemog/ufla-devops-shop/actions/runs/40418330394

```

### Conteúdo do arquivo ZIP

O ZIP da pasta de evidências contém:

- `pr-bloqueado.png`: captura do Pull Request bloqueado;
- `pr-corrigido.png`: captura do Pull Request ou execução corrigida;
- `execucao-aprovada.png`: captura da execução final aprovada;
- `trivy-reports.zip` ou os arquivos `trivy-fs.json` e `trivy-image.json`;
- `ufla-shop-sbom.cdx.json`.