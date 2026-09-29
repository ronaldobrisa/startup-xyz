# ADR 0003: Arquivamento automático em Glacier Deep Archive após 365 dias

Data: 2026-09-28 · Status: aceito

## Contexto

Documentos com mais de um ano raramente são lidos, mas têm valor estratégico para auditorias e
novos treinos de IA. Devem permanecer duráveis com o menor custo possível.

## Decisão

Regra de lifecycle no bucket de documentos: objetos sob `usuario-` transitam para
`DEEP_ARCHIVE` após 365 dias (variável `archive_after_days`). Versões não correntes seguem a
mesma regra. Uploads multipart abandonados são cancelados após 7 dias.

## Consequências

- Redução de cerca de 96% no custo por GB armazenado (S3 Standard ~US$ 0,023 contra
  Deep Archive ~US$ 0,00099 por GB-mês em us-east-1).
- Restauração leva até 12 horas (padrão) ou 48 horas (bulk); adequado para auditoria e treino,
  inadequado para acesso interativo. O RUNBOOK de produção precisa de um procedimento de restore.
- Objetos em Deep Archive têm cobrança mínima de 180 dias; excluir antes disso não economiza.
- Sem camada intermediária (Standard-IA) nesta fase: simplifica e a diferença de custo é pequena
  para o volume atual. Revisar quando houver dados reais de acesso.
