# Estimativa de custos (us-east-1, preços públicos de lista, sem impostos)

Cenário do PDF: **50 mil documentos por mês**, média de **12 MB** (≈ 600 GB novos por mês),
um download por documento, 500 usuários ativos por mês. Preços conferidos em setembro de 2026;
reproduza no [AWS Pricing Calculator](https://calculator.aws/) com os mesmos parâmetros para gerar o
link oficial (passo a passo no fim).

## Preços unitários usados

| Item | Preço |
|---|---|
| S3 Standard, armazenamento | US$ 0,023 por GB-mês |
| S3 Glacier Deep Archive, armazenamento | US$ 0,00099 por GB-mês |
| S3 PUT/POST | US$ 0,005 por mil |
| S3 GET | US$ 0,0004 por mil |
| S3 transição para Deep Archive | US$ 0,05 por mil objetos |
| S3 restauração Deep Archive (Bulk) | US$ 0,0025 por GB + US$ 0,025 por mil |
| Transferência de saída para internet | 100 GB por mês gratuitos, depois US$ 0,09 por GB |
| API Gateway REST | US$ 3,50 por milhão de requisições |
| Lambda (arm64) | US$ 0,20 por milhão de invocações + US$ 0,0000133 por GB-s; 1 milhão de invocações e 400 mil GB-s gratuitos por mês, para sempre |
| Lambda Provisioned Concurrency (arm64) | US$ 0,0000033 por GB-s provisionado |
| Cognito User Pools (Lite) | 10 mil usuários ativos por mês gratuitos, depois US$ 0,0055 por usuário |
| CloudWatch Logs | 5 GB de ingestão gratuitos, depois US$ 0,50 por GB |
| CloudWatch alarmes e dashboards | 10 alarmes e 3 dashboards gratuitos |
| SNS e-mail | 1.000 notificações gratuitas |

## Custo mensal no mês 12 (fim do ano 1, nada arquivado ainda)

| Serviço | Cálculo | US$/mês |
|---|---|---|
| S3 Standard | 7.200 GB × 0,023 | 165,60 |
| S3 requisições | 50 mil POST + 50 mil GET | 0,27 |
| Transferência de saída | 600 GB de downloads − 100 GB grátis = 500 GB × 0,09 | 45,00 |
| API Gateway | 100 mil × 3,50/milhão | 0,35 |
| Lambda | 100 mil invocações × 0,2 s × 0,25 GB = 5.000 GB-s | 0,00 (faixa gratuita) |
| Cognito | 500 usuários ativos | 0,00 |
| CloudWatch | < 1 GB de logs, 4 alarmes, 1 dashboard | 0,00 |
| **Total** | | **≈ 211** |

Leitura para a banca: **armazenamento e transferência são 99% do custo**; computação e API são
centavos. É isso que justifica investir em lifecycle e não em otimização de Lambda.

## Efeito do lifecycle no mês 24 (fim do ano 2)

| Cenário | Standard | Deep Archive | Transições | Total de armazenamento |
|---|---|---|---|---|
| Sem lifecycle | 14.400 GB × 0,023 = 331,20 | 0 | 0 | **331,20** |
| Com lifecycle (365 dias) | 7.200 GB × 0,023 = 165,60 | 7.200 GB × 0,00099 = 7,13 | 50 mil objetos/mês × 0,05/mil = 2,50 | **175,23** |

**Economia: ≈ US$ 156 por mês no ano 2**, crescendo a cada ano (cada ano completo migrado
economiza mais US$ 158 por mês). É a origem do "US$ 150+/mês no ano 2" do slide de FinOps.

## Provisioned Concurrency (só em prod)

1 instância × 0,5 GB × 2,6 milhões de segundos por mês × 0,0000033 ≈ **US$ 4,30 por mês** com
512 MB (≈ US$ 2,15 com 256 MB). Elimina o cold start de ~300 ms na primeira chamada; ligado por
variável apenas onde há SLA de latência.

## O que muda com 10 vezes mais demanda (500 mil documentos por mês)

| Serviço | US$/mês (mês 12) | Observação |
|---|---|---|
| S3 Standard | 1.656 | escala linear; lifecycle passa a economizar ~US$ 1.580 por mês no ano 2 |
| Transferência de saída | 531 | avaliar CloudFront (US$ 0,085 por GB e cache) ou cobrar egress do cliente |
| API Gateway | 3,50 | ainda irrelevante; HTTP API economizaria US$ 2,50 |
| Lambda | 0,60 | sai da faixa gratuita e continua irrelevante |
| Cognito | 0 a 27 | depende do número de usuários ativos, não de documentos |

Nenhum componente precisa ser redesenhado: o gargalo passa a ser financeiro (egress), não técnico.

## Custo da apresentação (ambiente demo, ligado por ~14 horas)

Menos de **US$ 0,05**: alguns KB no S3, poucas dezenas de requisições no API Gateway, Lambda e
Cognito na faixa gratuita, alarmes e dashboard gratuitos. O Budget de US$ 5 por mês da conta
alerta se algo ficar ligado.

## Reproduzindo no AWS Pricing Calculator

1. Região **US East (N. Virginia)**.
2. **Amazon S3**: S3 Standard 7.200 GB, 50.000 PUT, 50.000 GET, 600 GB de transferência de saída;
   adicionar S3 Glacier Deep Archive 7.200 GB e 50.000 requisições de lifecycle transition.
3. **Amazon API Gateway**: REST API, 0,1 milhão de requisições por mês.
4. **AWS Lambda**: arm64, 100.000 requisições, 200 ms, 256 MB.
5. **Amazon Cognito**: 500 MAU.
6. **Amazon CloudWatch**: 4 alarmes padrão, 1 dashboard, 1 GB de logs.
7. Salvar e compartilhar: o link gerado vai para o slide de custos.
