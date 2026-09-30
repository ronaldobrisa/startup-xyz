# Mudanças no deck (Gamma) para atender ao guia do TCC

Referência: *Manual do Aluno: Projeto TCC AWS* (10 pilares, 16 slides, 10 a 15 minutos).
O deck atual já segue a ordem do guia quase um a um; as mudanças abaixo fecham as lacunas.
Texto entre aspas está pronto para colar.

## Slide 1 · Capa

- Adicionar os nomes e papéis:
  "Ronaldo Brisa · Tech Lead (IaC e Plataforma) | Jéssica Barboza · FinOps | Pedro Paulo · Cloud Architect |
  Selliny Sampaio · Operations | Stephan Caldas · Security | Thieris · DevOps"
- Manter "JP2SRT Implantações em Cloud" e explicar na fala que são as iniciais da equipe.
- Adicionar "Case: Startup XYZ · Gestão, isolamento e arquivamento de ativos de IA".

## Slide 2 · Contexto do cliente

- Acrescentar o impacto do problema, que o guia pede: "Impacto: risco de expor documentos de um
  cliente a outro, custo de armazenamento crescendo 600 GB por mês sem política de retenção, e
  equipe pequena sem capacidade de operar servidores."

## Slide 3 · Requisitos

- Nos não funcionais, incluir: "Observabilidade: saber quando a API degrada sem olhar o console" e
  "Recuperação: RPO zero para documentos ativos".

## Slide 5 · Diagrama de arquitetura (a mudança mais importante)

- Substituir as quatro setas pela imagem `docs/arquitetura/diagrama.png` (1920 × 1080, mesmo fundo
  escuro). Ela mostra o fluxo numerado de 1 a 5, Cognito, autorizador, validador, IAM role com escopo
  de prefixo, S3 com todas as proteções, lifecycle, CloudWatch, SNS, Budgets e a pipeline com OIDC.
- Fala do Pedro: percorrer os números 1 a 5 e depois a faixa de segurança.

## Slide 6 · Fichamento dos componentes

- Adicionar dois cartões: "Amazon Cognito: identidade dos clientes; emite o token cujo claim vira
  o prefixo do tenant. Tier Lite, 10 mil usuários ativos gratuitos." e "Amazon CloudWatch + SNS:
  logs, 4 alarmes e dashboard; alerta por e-mail em minutos."
- Trocar o trade-off do cartão Serverless para: "Trade-off: cold start de ~300 ms na primeira
  chamada. Provisioned Concurrency implementada e ligada por ambiente (1 instância em produção,
  ~US$ 4/mês); desligada onde não há SLA de latência."

## Slide 7 · Justificativa e trade-offs

- Acrescentar a alternativa dentro do próprio API Gateway: "REST API escolhida em vez de HTTP API
  (70% mais barata) por validação de payload no gateway, usage plans por cliente e WAF. Na escala
  atual a diferença é de US$ 0,25 por mês." (ADR 0005)

## Slide 8 · Mapeamento de requisitos

Tabela atualizada:

| Requisito | Serviço AWS | Recurso implementado |
|---|---|---|
| Ingestão via API autenticada | API Gateway REST + Cognito | autorizador JWT, validador JSON Schema, throttling |
| Isolamento multi-tenant | Lambda + IAM + S3 | prefixo `usuario-{id}/` vindo do token, imposto no código e na IAM role |
| Recuperação segura | Lambda + S3 | presigned URL de 5 min, 403 fora do prefixo, 25 MB por upload |
| Arquivamento de longo prazo | S3 Lifecycle | Deep Archive após 365 dias; versões antigas expiram em 730 |
| Alta disponibilidade | infraestrutura AWS | multi-AZ nativo em S3, Lambda, API Gateway e Cognito |
| Controle de custos | S3 Classes + Budgets | lifecycle automático, Budget com alerta em 50 % e 100 % |
| Observabilidade | CloudWatch + SNS | 4 alarmes, dashboard, e-mail |
| Reprodutibilidade | Terraform + GitHub Actions | um código, N ambientes, apply/destroy em 2 minutos |

## Slide 9 · Escalabilidade

- Adicionar a resposta direta à pergunta do guia "e com 10 vezes mais usuários?": "500 mil
  documentos por mês: nenhum componente muda; Lambda escala para milhares de execuções, S3 não tem
  limite prático. O custo que cresce é armazenamento e transferência; a mitigação é CloudFront ou
  cobrar egress do cliente."
- Citar o gargalo real: "Limite de concorrência da Lambda na conta (1.000 por padrão): alarme de
  throttling avisa; aumento é um ticket."

## Slide 10 · Segurança

- Reorganizar nas três categorias do guia:
  - "Identidade: Cognito para clientes; IAM roles de mínimo privilégio para Lambda e pipeline;
    nenhuma chave de acesso de longa duração (OIDC)."
  - "Rede: sem VPC por decisão. Nenhum componente roda em rede privada; a superfície é o API
    Gateway com TLS, throttling e WAF opcional."
  - "Dados: SSE-S3, política que nega tráfego sem TLS, Block Public Access, versioning, URLs
    assinadas que expiram em 5 minutos e limitam 25 MB, validação de tipo de arquivo."
- Manter a pirâmide, adicionando "Layer 0: Cognito" no topo e "Validação de payload" na camada 2.

## Slide 11 · FinOps

- Adicionar a tabela de custo mensal do ano 2 (de `docs/custos/estimativa.md`): S3 Standard US$ 165,60,
  Deep Archive US$ 9,75, API US$ 0,19, CloudWatch US$ 0,90 (preço de lista), transferência de saída
  US$ 0 (60 GB, premissa de 10% de downloads, dentro da franquia), Lambda e Cognito US$ 0. Total US$ 176,70.
- Corrigir a poupança: "≈ US$ 156 por mês no ano 2 com lifecycle (331 → 175)".
- Incluir o link do AWS Pricing Calculator: https://calculator.aws/#/estimate?id=b94a26441f577ba9c387bc20a0e3a044c183c2e6
- Fala da Jéssica: "99 % do custo é armazenamento; computação é centavos. Por isso otimizamos classe de
  armazenamento, não Lambda. Assumimos 10 % de recuperação por usuários, 60 GB por mês, dentro da franquia
  gratuita; acima de 100 GB a transferência custa US$ 0,09 por GB e a mitigação é CloudFront ou repasse."

## Slide 12 · Resiliência

- Acrescentar a resposta ao guia "o que acontece se uma zona cair?": "Nada visível: S3, Lambda,
  API Gateway e Cognito são multi-AZ por padrão. Não existe instância para cair."

## Slide 13 · Proteção e recuperação

- Substituir o texto por RTO/RPO explícitos:

| Cenário | RPO | RTO |
|---|---|---|
| Documento apagado ou sobrescrito por engano | 0 (versão anterior) | minutos |
| Falha de uma zona de disponibilidade | 0 | 0, transparente |
| Perda da aplicação (Lambda, API, Cognito) | 0 | ≈ 2 min via `terraform apply` |
| Documento em Deep Archive | 0 | 12 h (Standard) ou 48 h (Bulk) |
| Falha regional | não coberto na Fase 1 | Fase 2: replicação entre regiões |

- Procedimento: "`aws s3api restore-object` com Tier Bulk; documentado no RUNBOOK."

## Slide 14 · IaC e roadmap

- Acrescentar "CI/CD: GitHub Actions valida e planeja em cada PR; apply e destroy manuais com
  confirmação; autenticação OIDC sem segredos no GitHub."
- Acrescentar "Documentação técnica: README, RUNBOOK e 6 ADRs no repositório."
- Roadmap Fase 2, mantendo Textract e Bedrock e somando: "replicação entre regiões, Object Lock
  para retenção legal, usage plans por cliente, CloudFront para downloads".

## Slide 15 · Demonstração

- Trocar o texto por três blocos com capturas: (1) `docs/apresentacao/evidencias/01-terraform-apply.png`
  (33 recursos em 72 s), (2) `docs/apresentacao/evidencias/02-smoke-test.png` (13 verificações, 403 em
  destaque), (3) dashboard do CloudWatch com os alarmes em OK, capturado no ensaio de 06/10 com o
  ambiente ligado.
- Fala do Ronaldo: rodar `mise run smoke` ao vivo, abrir o bucket e o dashboard, mostrar a aba
  Actions verde. Destroy fica para depois da banca.

## Slide 16 · Conclusão

- Reescrever nos quatro blocos do guia: "Problema: crescer 600 GB por mês com isolamento total e
  equipe pequena. Solução: serverless com isolamento por identidade e lifecycle automático.
  Benefícios: zero servidores, custo proporcional, −96 % no arquivamento, evidências auditáveis.
  Próximos passos: Textract e Bedrock, replicação entre regiões, usage plans por cliente."

## Estilo e tempo

- Português do Brasil uniforme ("ficheiro" → "arquivo", "utilizador" → "usuário", "gerir" → "gerenciar").
- 12 minutos no total; ver distribuição de falas no RUNBOOK.
