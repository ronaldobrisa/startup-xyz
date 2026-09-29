# ADR 0001: Serverless (API Gateway + Lambda + S3) em vez de EC2

Data: 2026-09-28 · Status: aceito

## Contexto

A Startup XYZ processa 50 mil documentos por mês com picos imprevisíveis e exige disponibilidade
acima de 99,9%, escalabilidade sem intervenção manual e custo governado por FinOps. A carga por
requisição é leve: validar identidade e emitir uma URL assinada.

## Decisão

Toda a camada de aplicação roda em serviços gerenciados: API Gateway REST como ponto de entrada,
uma função Lambda para a lógica e S3 como armazenamento. Nenhuma instância EC2, nenhum container.

## Consequências

- Custo zero em repouso; a demo completa custa menos de US$ 0,05.
- Sem sistema operacional para atualizar, sem Auto Scaling para configurar.
- Multi-AZ nativo em todos os componentes.
- Limite de 15 minutos por execução da Lambda: irrelevante para emissão de URLs. Processamento
  pesado (Textract, Bedrock) na Fase 2 deve usar eventos do S3 e não a mesma função.
- Cold start de algumas centenas de milissegundos na primeira chamada. Provisioned Concurrency
  está implementada no alias `live` e é ligada por ambiente pela variável `provisioned_concurrency`:
  0 em demo e dev (custo zero), 1 em prod (cerca de US$ 4 por mês com 512 MB). Cobra por tempo
  provisionado mesmo sem tráfego, por isso só onde há SLA de latência.
