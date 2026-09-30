# RUNBOOK: apresentação do TCC em 13/10/2026

Formato: 12 minutos de apresentação (guia recomenda 10 a 15) mais perguntas da banca.
Ambiente `demo` **já aplicado** antes da banca; ao vivo roda só o `smoke`, o console e o GitHub Actions.
Destroy depois da banca.

## Calendário

| Data | O quê | Responsável |
|---|---|---|
| 28/09 | Código, planos e documentação prontos; bootstrap e repositório criados | Ronaldo |
| até 03/10 | Ciclo completo local (apply, smoke, destroy, check-orphans) com tempos medidos; apply e destroy via GitHub Actions para provar a política de CI | Ronaldo |
| 06/10 | Ensaio com a equipe: ambiente aplicado antes, cada pessoa fala sua parte cronometrada, smoke ao vivo, destroy ao final | todos |
| 12/10 à noite | `mise run plan` + `apply` + `smoke` do ambiente da apresentação; deixar ligado (custo da noite: centavos) | Ronaldo |
| 13/10 | Apresentação; depois da banca `destroy` + `check-orphans` | todos / Ronaldo |

## Tempos medidos no primeiro ciclo completo (28/09, notebook, us-east-1)

| Etapa | Tempo | Observação |
|---|---|---|
| `mise run apply` | 72 s | 33 recursos; a regra de lifecycle do S3 é o item mais lento (~58 s) |
| `mise run smoke` | 42 s | 13 verificações OK |
| `mise run destroy` | 16 s | 33 recursos |
| `mise run check-orphans` | 5 a 40 s | a Tagging API pode listar o User Pool do Cognito por minutos após a exclusão; o script confirma na API do serviço antes de acusar |

## Distribuição de falas (12 min)

| Ordem | Quem | Slides | Tema | Tempo |
|---|---|---|---|---|
| 1 | Selliny Sampaio (Operations) | 2, 3 | contexto do cliente, requisitos funcionais e não funcionais | 2:00 |
| 2 | Pedro Paulo (Cloud Architect) | 4 a 8 | visão geral, diagrama numerado, serviços, justificativa, mapeamento de requisitos | 3:00 |
| 3 | Stephan Caldas (Security) | 10, 13 | camadas de segurança, multi-tenancy, RTO/RPO e restore | 1:30 |
| 4 | Jéssica Barboza (FinOps) | 11, 9 | custos por serviço, lifecycle, o que acontece com 10× | 1:30 |
| 5 | Thieris (DevOps) | 14, 12 | IaC, pipeline OIDC, ambientes, resiliência multi-AZ | 1:00 |
| 6 | Ronaldo Brisa (Tech Lead) | 15, 16 | demo ao vivo e conclusão | 3:00 |

Regra do guia: ninguém lê slide; a banca pode perguntar a qualquer um, então todos leem a seção
"Perguntas prováveis" inteira, não só a sua.

## Véspera (12/10)

- [ ] Console AWS > Billing: nenhuma fatura pendente, cartão válido
- [ ] `aws sts get-caller-identity` retorna a conta RBTI (a mesma do `.env`)
- [ ] `mise install && mise run lint` sem erros; `git status` limpo e `main` igual ao remoto
- [ ] `mise run check-orphans` passa (nada sobrou do ensaio)
- [ ] `mise run plan` mostra 33 criações → revisar → `mise run apply` → `mise run smoke` com 10 OK
- [ ] `mise run dashboard` abre e os 4 alarmes estão em OK (podem ficar em "dados insuficientes" até o primeiro tráfego)
- [ ] Console com abas abertas e logadas: S3 (bucket demo), Cognito (usuários 123 e 456), CloudWatch (dashboard), GitHub Actions
- [ ] Terminal com fonte grande, `.smoke/` limpo, notebook na tomada, hotspot do celular testado
- [ ] `gh auth status` OK (plano B via Actions)
- [ ] Capturas para o slide 15: `plan/apply` do ensaio, saída do `smoke`, dashboard

## Roteiro da demo (Ronaldo, 3 min)

| Tempo | Ação | O que dizer |
|---|---|---|
| 0:00 | Mostrar slide 15 com a captura do `apply` | "Tudo isso subiu com um comando, 33 recursos em cerca de 2 minutos, e desce com outro. O ambiente está no ar agora." |
| 0:20 | `mise run smoke` | Narrar conforme as seções passam: usuários criados no Cognito → upload pelo presigned POST → download idêntico → **403 do usuário 456** → 401 sem token → 400 do validador antes da Lambda → 404 → upload grande rejeitado pelo S3 → 403 na URL pública → configuração do bucket e alarmes |
| 1:20 | Console S3 | "Só um prefixo por cliente. Block Public Access total, versioning, lifecycle de 365 dias para Deep Archive." |
| 1:50 | Console CloudWatch (dashboard) | "Requisições da demo aparecendo aqui. Quatro alarmes; qualquer 5XX chega por e-mail em um minuto." |
| 2:20 | GitHub > Actions | "Cada PR roda validação e plan; apply e destroy são manuais com confirmação; autenticação OIDC, zero segredos." |
| 2:45 | Slide 16 | conclusão em quatro blocos: problema, solução, benefícios, próximos passos |

Se sobrar tempo: `lambda/handler.py` na checagem `key.startswith(prefix)` e `terraform/iam.tf` na
política `TenantObjects` (defesa em profundidade).

## Se algo falhar

| Sintoma | Ação |
|---|---|
| `smoke` falha em um passo | Reexecutar; é idempotente. Um 5xx isolado costuma ser cold start do autorizador. Se persistir, mostrar as capturas do ensaio e seguir. |
| Sem rede no notebook | Plano B: pelo celular, GitHub > Actions > *Deploy (manual)* não ajuda no smoke; usar as capturas e o console pelo celular. |
| Ambiente caiu antes da banca | `mise run plan && mise run apply` leva ~2 min; ou GitHub > Actions > *Deploy (manual)* > `apply`, `demo`, `demo`. |
| Lock do estado preso | `terraform -chdir=terraform force-unlock <ID>` (o ID está na mensagem). |
| `destroy` falha depois | Reexecutar `mise run destroy-plan && mise run destroy`; se persistir, `mise run ci-deploy destroy`. `check-orphans` lista o que sobrou. |

## Depois da banca

- [ ] `mise run destroy-plan` → revisar → `mise run destroy` → `mise run check-orphans`
- [ ] Bootstrap (bucket de estado, role, SNS, Budget) permanece; custo mensal: centavos
- [ ] Opcional: `mise run repo-public`

## Recuperação (para o slide 13 e perguntas)

| Cenário | RPO | RTO | Como |
|---|---|---|---|
| Documento apagado ou sobrescrito | 0 | minutos | versioning: restaurar a versão anterior no console ou `copy-object` da versão |
| Falha de uma AZ | 0 | 0 | S3, Lambda, API Gateway e Cognito são multi-AZ; nada a fazer |
| Perda da aplicação | 0 | ≈ 2 min | `mise run apply`; dados no S3 intactos (`force_destroy = false` em prod) |
| Documento em Deep Archive | 0 | 12 h Standard / 48 h Bulk | `mise run restore-example <key>` imprime os comandos |
| Falha regional | não coberto | Fase 2 | replicação entre regiões para um bucket em outra região |

## Perguntas prováveis da banca

**Arquitetura (Pedro)**
- Por que serverless e não EC2? Custo zero em repouso, sem SO para manter, multi-AZ nativo; a carga é leve (assinar URLs). ADR 0001.
- Por que REST e não HTTP API? Validação de payload no gateway, usage plans, WAF; diferença de US$ 0,25 por mês na escala atual. ADR 0005.
- Por que um bucket com prefixos e não um bucket por cliente? Limite de 1.000 buckets, lifecycle e métricas configurados uma vez; isolamento pela IAM role e pelo código. ADR 0002.
- Onde está o gargalo? Concorrência da Lambda na conta (1.000 padrão); alarme de throttling avisa e o aumento é um ticket.

**Segurança (Stephan)**
- Quem pode acessar? Só o dono do prefixo, identificado pelo token do Cognito; a role da Lambda nem alcança outros prefixos.
- Como evitaram exposição indevida? Block Public Access, política só TLS, URLs de 5 minutos, 25 MB, validação de tipo, cliente não escolhe o próprio id.
- E se o código tiver um bug? A IAM role só permite `usuario-*/*`; defesa em profundidade.
- Por que não VPC? Nada roda em rede privada; VPC adicionaria NAT e custo sem proteger nada aqui.

**Custos (Jéssica)**
- Recurso mais caro? Armazenamento S3 Standard (US$ 165 por mês), 99% do total de US$ 176,70 no ano 2. Computação é centavos. Transferência de saída fica na franquia gratuita com 10% de downloads (60 GB); acima de 100 GB custa US$ 0,09 por GB.
- Como reduziriam? Lifecycle já reduz 96 % por GB arquivado; próximo passo é CloudFront ou cobrar egress; Intelligent-Tiering se o padrão de acesso for imprevisível.
- Com 10× a demanda? Linear em S3 e egress; nada muda na arquitetura. `docs/custos/estimativa.md`.

**Escalabilidade e resiliência (Thieris)**
- Se uma instância cair? Não há instância. Se uma AZ cair, nada visível.
- Pico de acesso? Lambda escala de 0 a mil execuções paralelas; throttling do API Gateway protege o backend; alarme avisa.
- Como recriar tudo em outra conta? `mise run bootstrap-apply` e `mise run apply` com outro tfvars; 5 minutos.

**Operação e recuperação (Selliny)**
- Como sabem que está saudável? Dashboard e 4 alarmes com e-mail. Nada de ficar olhando console.
- Documento apagado por engano? Versioning; RTO de minutos.
- Documento de 3 anos atrás? Está em Deep Archive; restore Bulk em até 48 h, Standard em até 12 h.

**Demo e evolução (Ronaldo)**
- Por que Terraform? Reprodutibilidade, revisão em PR, um código para N ambientes; a demo sobe e desce em minutos.
- Como fica daqui a um ano? Fase 2: Textract e Bedrock por eventos do S3, replicação entre regiões, usage plans por cliente, Object Lock para retenção legal.
