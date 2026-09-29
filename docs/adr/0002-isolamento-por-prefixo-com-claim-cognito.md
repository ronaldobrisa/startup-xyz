# ADR 0002: Isolamento multi-tenant por prefixo S3 com identidade vinda do Cognito

Data: 2026-09-28 · Status: aceito

## Contexto

Cada cliente só pode ver os próprios documentos. As alternativas eram um bucket por cliente,
um prefixo por cliente no mesmo bucket, ou tabelas de ACL por objeto.

## Decisão

Um único bucket com prefixo `usuario-{id}/` por cliente. O `id` é o claim `cognito:username` do
ID token validado pelo autorizador do API Gateway; o cliente nunca informa o próprio id.
O isolamento é aplicado em duas camadas independentes:

1. **Código**: a Lambda só assina URLs cuja key começa com o prefixo do usuário autenticado
   e responde 403 fora dele.
2. **IAM**: a role da Lambda só tem `s3:GetObject` e `s3:PutObject` em `usuario-*/*`.
   Um bug no código não alcança nada fora desse padrão.

Complementos: Block Public Access total, política de bucket que nega tráfego sem TLS,
presigned URLs com validade de 5 minutos.

## Consequências

- Um bucket só: lifecycle, versioning e métricas configurados uma vez.
- Usernames são imutáveis no Cognito com criação exclusiva por administrador, o que torna
  o prefixo estável. Se no futuro o username for o e-mail do cliente, trocar para o claim `sub`.
- Limite de 1.000 buckets por conta deixa de ser um problema para milhares de clientes.
- Auditoria por cliente é um filtro de prefixo no S3 Inventory ou no CloudTrail.
