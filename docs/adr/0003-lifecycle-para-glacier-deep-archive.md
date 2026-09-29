# ADR 0003: Arquivamento automático em Glacier Deep Archive após 365 dias

Data: 2026-09-28 · Status: aceito

## Contexto

Documentos com mais de um ano raramente são lidos, mas têm valor estratégico para auditorias e
novos treinos de IA. Devem permanecer duráveis com o menor custo possível.

## Decisão

Regra de lifecycle no bucket de documentos: objetos sob `usuario-` transitam para
`DEEP_ARCHIVE` após 365 dias (variável `archive_after_days`). Versões não correntes seguem a
mesma regra e expiram após 730 dias (`noncurrent_version_expiration_days`); marcadores de exclusão
órfãos são removidos. Uploads multipart abandonados são cancelados após 7 dias.

## Consequências

- Redução de cerca de 96% no custo por GB armazenado (S3 Standard ~US$ 0,023 contra
  Deep Archive ~US$ 0,00099 por GB-mês em us-east-1). Economia estimada de US$ 156 por mês no
  ano 2 para o cenário de 50 mil documentos por mês (`docs/custos/estimativa.md`).
- Restauração leva até 12 horas (Standard) ou 48 horas (Bulk); adequado para auditoria e treino,
  inadequado para acesso interativo. Procedimento em `mise run restore-example` e no RUNBOOK.
- Versões antigas protegem contra exclusão acidental por dois anos e depois somem, evitando
  acumular custo indefinidamente.
- Objetos em Deep Archive têm cobrança mínima de 180 dias; excluir antes disso não economiza.
- Sem camada intermediária (Standard-IA) nesta fase: simplifica e a diferença de custo é pequena
  para o volume atual. Revisar quando houver dados reais de acesso.
