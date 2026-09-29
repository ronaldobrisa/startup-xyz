# Startup XYZ: plataforma serverless de documentos

Implementação em Terraform da arquitetura descrita em *Arquitetura Serverless AWS para a Startup XYZ*
(JP2SRT Implantações em Cloud): ingestão e recuperação segura de documentos com isolamento por cliente,
arquivamento automático e custo proporcional ao uso.

```
cliente ──(ID token Cognito)──▶ API Gateway REST ──▶ Lambda (Python) ──▶ presigned URL
                                     │                    │
                               autorizador Cognito     IAM: só usuario-*/
                                                          │
                                                          ▼
                                             S3  usuario-{id}/documento.pdf
                                             versioning · SSE · Block Public Access
                                             lifecycle: 365 d ──▶ Glacier Deep Archive
```

| Requisito do PDF | Como está implementado |
|---|---|
| Ingestão via API autenticada | API Gateway REST + autorizador Cognito User Pools ([api.tf](terraform/api.tf), [cognito.tf](terraform/cognito.tf)) |
| Isolamento multi-tenant | Prefixo `usuario-{cognito:username}/` imposto no código **e** na política IAM da Lambda ([handler.py](lambda/handler.py), [iam.tf](terraform/iam.tf)) |
| Block Public Access | Bloqueio total no bucket + política que nega tráfego sem TLS ([s3.tf](terraform/s3.tf)) |
| Presigned URLs | Geradas pela Lambda com validade de 5 minutos |
| Arquivamento após 365 dias | Regra de lifecycle para `DEEP_ARCHIVE`, incluindo versões antigas |
| Versioning | Habilitado no bucket de documentos |
| IaC com ambientes idênticos | Um root module, um `envs/<ambiente>.tfvars` por ambiente |
| Pipeline | GitHub Actions via OIDC: validação e plan em PR, apply/destroy manual |

## Pré-requisitos

- [mise](https://mise.jdx.dev) (instala Terraform, tflint, jq e gh nas versões fixadas em [mise.toml](mise.toml))
- AWS CLI v2 configurada com credenciais da conta (perfil `default`, região `us-east-1`)
- `curl` e `openssl` (já vêm com o Git Bash no Windows)

```bash
mise install
mise run lint
```

## Estrutura

```
terraform/
  bootstrap/      recursos permanentes: bucket de estado, role OIDC do GitHub, Budget
  envs/           demo.tfvars, dev.tfvars, prod.tfvars
  versions.tf     providers, backend S3 (lock nativo), default_tags
  s3.tf cognito.tf lambda.tf api.tf iam.tf outputs.tf variables.tf
lambda/handler.py Lambda única: POST /documents e GET /documents/{key+}
scripts/          smoke.sh (prova ao vivo) e check-orphans.sh (prova de conta limpa)
docs/adr/         decisões de arquitetura
RUNBOOK.md        roteiro minuto a minuto da apresentação
```

## Bootstrap (uma vez por conta)

```bash
mise run bootstrap-plan     # revise o plano
mise run bootstrap-apply    # cria bucket de estado, role gh-actions-startup-xyz e Budget de US$ 5
```

Depois, configure as variáveis do repositório no GitHub com os outputs:

```bash
gh variable set AWS_REGION --body us-east-1
gh variable set AWS_STATE_BUCKET --body startup-xyz-tfstate-<conta>
gh variable set TERRAFORM_ROLE_ARN --body arn:aws:iam::<conta>:role/gh-actions-startup-xyz
```

## Ciclo da demo

```bash
mise run plan            # terraform plan do ambiente demo (gera tfplan)
mise run apply           # aplica o tfplan revisado
mise run smoke           # upload, download, 403 entre usuários, 401 sem token, Block Public Access, lifecycle
mise run destroy-plan    # plano de destruição
mise run destroy         # aplica a destruição
mise run check-orphans   # falha se sobrar qualquer recurso com as tags do projeto
mise run demo [--pause]  # tudo acima em sequência
```

Outro ambiente: `ENV=dev mise run plan` (usa `envs/dev.tfvars` e a key `dev/terraform.tfstate`).

## API

| Método | Rota | Body / parâmetro | Resposta |
|---|---|---|---|
| `POST` | `/documents` | `{"filename": "contrato.pdf", "content_type": "application/pdf"}` | `201 {key, upload_url, method, headers, expires_in}` |
| `GET` | `/documents/{key+}` | key completa, ex.: `usuario-123/contrato.pdf` | `200 {key, download_url, expires_in}`; `403` se a key for de outro usuário; `404` se não existir |

Header obrigatório: `Authorization: <ID token do Cognito>`. Tipos aceitos: PDF, PNG, JPEG.

## Custo

Ambiente `demo` de ponta a ponta (apply, smoke, destroy) fica abaixo de US$ 0,05: Lambda e Cognito Lite
estão na faixa gratuita permanente, e API Gateway, S3 e CloudWatch cobram frações de centavo por
dezenas de requisições. O Budget mensal de US$ 5 (criado no bootstrap) alerta por e-mail se algo ficar ligado.

Fora do escopo desta fase: Provisioned Concurrency, domínio customizado, Textract e Bedrock (Fase 2).
