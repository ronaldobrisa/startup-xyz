# ADR 0004: Estado remoto no S3 com lock nativo e GitHub Actions via OIDC

Data: 2026-09-28 · Status: aceito

## Contexto

O Terraform precisa de estado compartilhado entre o notebook do operador e a pipeline, e a
pipeline precisa de credenciais AWS sem chaves de longa duração no GitHub.

## Decisão

- **Bootstrap separado** (`terraform/bootstrap`, estado local, aplicado uma vez): bucket
  `startup-xyz-tfstate-<conta>` versionado, criptografado e sem acesso público; role
  `gh-actions-startup-xyz`; tópico SNS de alertas com assinatura de e-mail; AWS Budget de US$ 5
  por mês para a conta inteira (filtro por tag exigiria ativar a tag de alocação de custos no
  Billing e levaria até 24 horas para valer).
- **Backend S3 com `use_lockfile = true`** (Terraform 1.10+): lock via objeto `.tflock`,
  sem tabela DynamoDB. Uma key por ambiente: `<ambiente>/terraform.tfstate`.
- **OIDC** com o provedor `token.actions.githubusercontent.com` já existente na conta. A trust
  policy aceita apenas o repositório `ronaldobrisa/startup-xyz` na branch `main` e em pull requests.
- **Mínimo privilégio** na role de CI: cada serviço restrito por ARN ao prefixo `startup-xyz-*`;
  S3 só nos buckets `startup-xyz-*-documents-<conta>` (nunca o bucket de estado, onde a role tem
  apenas leitura e escrita de objetos); IAM só em roles com esse prefixo e `PassRole` apenas para
  o Lambda; CloudWatch só em alarmes e dashboards do projeto.
- **Apply nunca é automático**: PR e push em `main` rodam validação e plan; apply e destroy
  exigem `workflow_dispatch` com confirmação do nome do ambiente.

## Consequências

- Zero segredos no GitHub: só três variáveis não sensíveis (região, bucket, ARN da role).
- O bootstrap e o Budget sobrevivem ao destroy da demo, como rede de segurança de custo.
- Se uma ação IAM faltar na política de CI, o Terraform falha nomeando a ação; adiciona-se
  ao bootstrap. Fallback aceitável: `PowerUserAccess` + IAM restrito por prefixo.
- Ambientes protegidos com aprovadores do GitHub não estão disponíveis em repositório privado
  no plano gratuito; a confirmação por input substitui essa proteção nesta fase.
