# RUNBOOK: apresentação de 13/10/2026

Tempo alvo: 5 minutos. Ensaio completo: 06/10/2026 (preencher os tempos medidos abaixo).

## Véspera (12/10)

- [ ] `aws sts get-caller-identity` retorna a conta 992382426972
- [ ] Console AWS > Billing: nenhuma fatura pendente, cartão válido
- [ ] `mise install && mise run lint` sem erros
- [ ] `git status` limpo e `main` igual ao remoto
- [ ] `mise run plan` mostra apenas criações (nenhum recurso `demo` sobrou de antes)
- [ ] `mise run check-orphans` passa (conta limpa)
- [ ] Terminal com fonte grande, dois painéis: comandos à esquerda, console AWS à direita (S3 e Cognito)
- [ ] Notebook na tomada, Wi-Fi testado, hotspot do celular como reserva
- [ ] `gh auth status` OK (plano B via GitHub Actions)

## Roteiro

| Min | Comando | O que dizer enquanto roda | Tempo medido (06/10) |
|---|---|---|---|
| 0:00 | `mise run plan` | "Tudo é código: este plano lista cada recurso que a AWS vai criar. Nada é clicado no console." | ___ s |
| 0:30 | `mise run apply` | "API Gateway, Lambda, Cognito, S3 com lifecycle e IAM sobem juntos. Serverless: zero servidores, custo zero em repouso." | ___ s |
| 2:00 | `mise run smoke` | Apontar na tela: (1) key `usuario-123/`, (2) PUT 200, (3) download idêntico, (4) **403** do usuário 456, (5) 401 sem token, (6) 403 na URL pública, (7) lifecycle 365 d → DEEP_ARCHIVE | ___ s |
| 3:00 | `mise run destroy-plan && mise run destroy` | "Ambiente efêmero: o mesmo código desfaz tudo. Em produção, `force_destroy=false` e proteção do User Pool impedem isso." | ___ s |
| 4:15 | `mise run check-orphans` | "Prova de conta limpa: nenhum recurso com a tag do projeto sobrou. FinOps começa aqui." | ___ s |
| 4:30 | Mostrar aba Actions do repositório | "A mesma pipeline roda validação e plan em cada PR e tem apply/destroy manual como reserva." | |

Se sobrar tempo: abrir `lambda/handler.py` na linha da checagem `key.startswith(prefix)` e `iam.tf`
na política `TenantObjects` para mostrar a defesa em profundidade.

## Se algo falhar

| Sintoma | Ação |
|---|---|
| `apply` falha no meio | Rodar `mise run apply` de novo (Terraform retoma de onde parou). Se persistir, narrar pelo plano e pular para o plano B. |
| `smoke` falha em um passo | Reexecutar `mise run smoke`; é idempotente. Um 5xx isolado costuma ser cold start do autorizador. |
| Notebook sem rede ou travado | Plano B: no celular, GitHub > Actions > *Deploy (manual)* > `apply`, `demo`, `demo`. Depois `destroy` da mesma forma. |
| `destroy` falha | Reexecutar `mise run destroy-plan && mise run destroy`. Se persistir, `mise run ci-deploy destroy` pelo GitHub. |
| `check-orphans` acusa sobras | Anotar os ARNs, terminar a apresentação, remover depois. O Budget alerta se custar algo. |
| Lock do estado preso | `terraform -chdir=terraform force-unlock <ID>` (o ID aparece na mensagem de erro). |

## Depois da apresentação

- [ ] `mise run check-orphans` passa
- [ ] Opcional: `mise run repo-public`
- [ ] Bootstrap (bucket de estado, role, Budget) permanece; custo mensal esperado: centavos
