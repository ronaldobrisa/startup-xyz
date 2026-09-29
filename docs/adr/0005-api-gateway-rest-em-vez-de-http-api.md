# ADR 0005: API Gateway REST em vez de HTTP API

Data: 2026-09-28 · Status: aceito

## Contexto

O API Gateway oferece dois produtos para o mesmo caso de uso. A banca tende a perguntar por que
não escolhemos o mais barato.

| Critério | REST API | HTTP API |
|---|---|---|
| Preço (us-east-1, primeiros 333 milhões) | US$ 3,50 por milhão de requisições | US$ 1,00 por milhão |
| Autenticação Cognito | Autorizador Cognito User Pools (ID token) | Autorizador JWT nativo |
| Validação de payload (JSON Schema) antes da Lambda | Sim (modelos + validador) | Não |
| Throttling por método e usage plans com API keys | Sim | Só por stage/rota |
| Integração com AWS WAF | Sim | Não |
| Latência adicional típica | ~10 a 30 ms a mais | menor |
| Cache de respostas, transformações de request/response | Sim | Não |

## Decisão

REST API. Motivos concretos no projeto:

1. **Validação de payload** no gateway: o `POST /documents` só chega à Lambda se o body obedecer ao
   modelo `UploadRequest` (nome de arquivo com padrão seguro, `content_type` no enum). Requisição
   malformada é rejeitada com 400 sem custo de invocação e sem chance de bug no código. É a
   "validação e transformação" prometida no slide de mapeamento de requisitos.
2. **Caminho para usage plans e WAF**: clientes da Startup XYZ terão cotas por contrato; usage
   plans com API keys por tenant e regras WAF (rate limit por IP, bloqueio geográfico) só existem
   no REST.
3. **Custo irrelevante na escala atual**: 50 mil uploads e 50 mil downloads por mês são 100 mil
   requisições, ou US$ 0,35 no REST contra US$ 0,10 no HTTP API. A diferença fica abaixo de
   US$ 0,30 por mês frente a US$ 165 de armazenamento.

## Consequências

- Quando o volume ultrapassar dezenas de milhões de requisições por mês, a diferença de preço
  passa a importar; a migração é mecânica porque a Lambda usa o formato proxy em ambos.
- REST exige o recurso `aws_api_gateway_deployment` com trigger de redeploy; o Terraform cuida.
- O autorizador Cognito do REST valida o **ID token**; o access token precisaria de escopos
  OAuth configurados. O smoke test usa o ID token por isso.
