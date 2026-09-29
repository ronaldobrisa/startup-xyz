# ADR 0006: Observabilidade com CloudWatch e alertas via SNS

Data: 2026-09-28 · Status: aceito

## Contexto

Requisito não funcional de disponibilidade acima de 99,9% e operação sem servidores exigem saber,
sem olhar o console, quando a API degrada. O guia do TCC lista dashboard, alarmes e monitoramento
como diferenciais.

## Decisão

- **Logs** estruturados em JSON da Lambda, com retenção por ambiente (1 dia na demo, 90 em prod).
- **Métricas detalhadas** habilitadas no stage do API Gateway (`metrics_enabled`).
- **Quatro alarmes**, todos publicando em um tópico SNS criado no bootstrap e assinado por e-mail:

| Alarme | Métrica | Limite | Significado |
|---|---|---|---|
| `*-api-5xx` | API Gateway 5XXError, soma por minuto | ≥ 1 | falha na Lambda ou na integração |
| `*-api-latency-p99` | API Gateway Latency p99, 5 min | > 3.000 ms em 2 períodos | degradação percebida pelo cliente |
| `*-lambda-errors` | Lambda Errors, soma por minuto | ≥ 1 | exceção não tratada |
| `*-lambda-throttles` | Lambda Throttles, soma por minuto | ≥ 1 | pico acima da concorrência da conta |

- **Dashboard** CloudWatch por ambiente: requisições e erros da API, latência p50/p99, invocações,
  erros, throttles, duração e concorrência da Lambda, número de objetos e bytes no bucket, e o
  estado dos alarmes.

## Alternativas consideradas

- **X-Ray** para rastreamento distribuído: útil quando houver mais de um salto (Fase 2 com
  Textract e Bedrock); hoje o único salto é API → Lambda → S3 e os logs bastam.
- **Ferramenta externa (Datadog, Grafana)**: custo e mais um fornecedor para um time pequeno.
- **Alarmes sem SNS**: apareceriam no console, mas ninguém seria avisado.

## Consequências

- Custo zero: 10 alarmes e 3 dashboards estão na faixa gratuita permanente; e-mail via SNS é gratuito.
- A assinatura de e-mail do SNS precisa ser confirmada uma vez (link recebido no apply do bootstrap).
- O tópico vive no bootstrap para sobreviver ao destroy dos ambientes; os alarmes referenciam o
  ARN construído por convenção de nome, sem leitura em tempo de apply.
