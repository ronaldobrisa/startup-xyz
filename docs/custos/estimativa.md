# Estimativa de custos (us-east-1, preços públicos de lista, sem impostos)

Cenário do PDF: **50 mil documentos por mês**, média de **12 MB** (≈ 600 GB novos por mês),
um download por documento, 500 usuários ativos por mês. Preços conferidos em setembro de 2026;
reproduza no [AWS Pricing Calculator](https://calculator.aws/) com os mesmos parâmetros para gerar o
link oficial (passo a passo no fim).

## Preços unitários usados

Coluna "Validação": **API** = confirmado em 28/09/2026 pela AWS Price List API (`aws pricing get-products`,
us-east-1); **lista** = preço público da página do serviço, não exposto pela API com os filtros disponíveis,
confirmar no Calculator.

| Item | Preço | Validação |
|---|---|---|
| S3 Standard, armazenamento | US$ 0,023 por GB-mês (primeiros 50 TB) | API |
| S3 Glacier Deep Archive, armazenamento | US$ 0,00099 por GB-mês | lista |
| S3 PUT/POST | US$ 0,005 por mil | API |
| S3 GET | US$ 0,0004 por mil | API |
| S3 transição para Deep Archive | US$ 0,05 por mil objetos | API |
| S3 restauração Deep Archive (Bulk) | US$ 0,0025 por GB + US$ 0,025 por mil | lista |
| Transferência de saída para internet | 100 GB por mês gratuitos, depois US$ 0,09 por GB (primeiros 10 TB) | API |
| API Gateway REST | US$ 3,50 por milhão de requisições | lista |
| API Gateway HTTP API (alternativa, ADR 0005) | US$ 1,00 por milhão | API |
| Lambda (arm64) | US$ 0,20 por milhão de invocações + US$ 0,0000133 por GB-s; 1 milhão de invocações e 400 mil GB-s gratuitos por mês, para sempre | API |
| Lambda Provisioned Concurrency (arm64) | US$ 0,0000033 por GB-s provisionado | API |
| Cognito User Pools (Lite) | 10 mil usuários ativos por mês gratuitos, depois US$ 0,0055 por usuário | API |
| CloudWatch Logs | 5 GB de ingestão gratuitos, depois US$ 0,50 por GB | lista |
| CloudWatch alarmes e dashboards | 10 alarmes e 3 dashboards gratuitos | lista |
| SNS e-mail | 1.000 notificações gratuitas | lista |

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

## Reproduzindo no AWS Pricing Calculator (gera o link para o slide 11)

O Calculator não tem API; o link de compartilhamento só é criado dentro do site. Roteiro de cliques,
cerca de 10 minutos:

1. Abrir https://calculator.aws/#/createCalculator e clicar em **Create estimate**. Nome da estimativa:
   `Startup XYZ - 50k documentos/mes - ano 1 (mes 12)`.
2. **Add service** → buscar `S3` → **Configure** → região **US East (N. Virginia)**:
   - S3 Standard: *Storage amount* 7.200 GB por mês; *PUT, COPY, POST, LIST requests* 50.000;
     *GET, SELECT, and all other requests* 50.000; *Data returned by S3 Select* 0.
   - Marcar **S3 Glacier Deep Archive**: *Storage amount* 7.200 GB; *Lifecycle Transition requests into
     Deep Archive* 50.000; *Data retrieval* 0.
   - Em **Data transfer**: *Outbound data transfer* → Internet, 600 GB por mês.
   - **Save and add service**.
3. `API Gateway` → **REST API**: *Requests* 0,1 milhão por mês; cache desligado → **Save and add service**.
4. `Lambda` → arquitetura **Arm**: *Number of requests* 100.000 por mês; *Duration* 200 ms;
   *Memory* 256 MB; *Ephemeral storage* 512 MB → **Save and add service**.
5. `Cognito` → **User Pools**: *Monthly active users* 500; tier **Lite** → **Save and add service**.
6. `CloudWatch`: *Standard logs data ingested* 1 GB; *Number of alarms (standard resolution)* 4;
   *Number of dashboards* 1 → **Save and add service**.
7. Em **My estimate**: **Share** → **Agree and continue** → copiar o link público. Ele vai para o slide 11
   e para a seção "Custo" do README.
8. Opcional, segunda estimativa `ano 2 (mes 24) com lifecycle`: S3 Standard 7.200 GB + Deep Archive
   7.200 GB; e uma terceira `ano 2 sem lifecycle`: S3 Standard 14.400 GB. A diferença entre as duas é
   a economia de ≈ US$ 156 por mês do slide de FinOps.

Resultado esperado no Calculator para o mês 12: ≈ US$ 211 por mês. Se o total divergir mais de 5 %,
a causa provável é a franquia de 100 GB de transferência (o Calculator pode não descontar) ou o
Lambda fora da faixa gratuita (desmarcar "Free Tier" só se a conta já a tiver esgotado).
