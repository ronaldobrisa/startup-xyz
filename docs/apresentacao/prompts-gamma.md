# Comandos para o editor de IA do Gamma, slide a slide

Uso: abra o cartão, clique em "Editar com IA", cole o comando inteiro, aplique e revise.
Se o Gamma reformatar demais, desfaça e cole de novo pedindo "mantenha o layout atual".
Imagens do repositório (diagrama) precisam ser arrastadas manualmente para o cartão.

## Comando global (aplicar primeiro, no deck inteiro)

```
Revise todo o texto do deck para português do Brasil, sem mudar o conteúdo nem o layout:
troque "ficheiro" por "arquivo", "utilizador" por "usuário", "gerir" por "gerenciar",
"defeito" (no sentido de padrão) por "padrão", "controlo" por "controle", "poupança" por "economia".
Mantenha termos técnicos em inglês (serverless, lifecycle, presigned URL, Block Public Access).
```

## Slide 1 · Capa

```
Mantenha o título e o subtítulo. Substitua a lista de papéis por uma lista com nome e papel de cada
integrante, nesta ordem: Ronaldo Brisa · Tech Lead (IaC e Plataforma); Jéssica Barboza · FinOps;
Pedro Paulo · Cloud Architect; Selliny Sampaio · Operations; Stephan Caldas · Security; Thieris · DevOps.
Abaixo, uma linha pequena: "Equipe JP2SRT · Case: Startup XYZ — gestão, isolamento e arquivamento de
ativos de IA · TCC AWS". Não altere a imagem.
```

## Slide 2 · Contexto do cliente

```
Mantenha tudo e acrescente, após os requisitos não funcionais, um bloco curto chamado "Impacto do
problema" com três itens: "Risco de expor documentos de um cliente a outro"; "Armazenamento crescendo
600 GB por mês sem política de retenção"; "Equipe pequena, sem capacidade de operar servidores".
```

## Slide 3 · Levantamento de requisitos

```
Na coluna de requisitos não funcionais, acrescente dois cartões no mesmo estilo dos existentes:
"Observabilidade — saber quando a API degrada sem olhar o console" e "Recuperação — RPO zero para
documentos ativos e restauração garantida do arquivo frio". Mantenha os seis cartões atuais.
```

## Slide 4 · Fluxo simplificado

```
Mantenha o layout de três etapas. No texto da etapa "Entrada Segura", troque por: "O usuário se autentica
no Cognito e envia o pedido com o token pela API." Na etapa "Processamento Leve": "A função valida o
token, gera um acesso assinado ao armazenamento válido por 5 minutos e limitado a 25 MB." Na etapa
"Armazenamento & Ciclo de Vida": "Arquivos gravados com isolamento por usuário e migrados para a camada
fria após 1 ano."
```

## Slide 5 · Diagrama de arquitetura

```
Remova as quatro setas de texto. Deixe o título "Fluxo Serverless End-to-End" e um espaço de imagem
em largura total para um diagrama 16:9 com fundo escuro. Abaixo da imagem, uma legenda de uma linha:
"Fluxo numerado 1 a 5: login no Cognito, chamada autenticada, invocação da Lambda, URL assinada,
upload direto no S3. Segurança em cinco camadas, observabilidade e entrega por IaC."
```

Depois: arraste `docs/arquitetura/diagrama.png` para o espaço de imagem.

## Slide 6 · Fichamento dos componentes

```
Mantenha os quatro cartões e acrescente dois no mesmo estilo. "Amazon Cognito: identidade dos clientes.
Emite o token cujo claim vira o prefixo do tenant no S3. Tier Lite, 10 mil usuários ativos gratuitos."
"Amazon CloudWatch + SNS: logs estruturados, quatro alarmes e dashboard; alerta por e-mail em um minuto."
No cartão "Modelo Serverless", troque o trade-off por: "Trade-off: cold start de ~300 ms na primeira
chamada. Provisioned Concurrency implementada e ligada por ambiente (1 instância em produção, ~US$ 4/mês);
desligada onde não há SLA de latência."
```

## Slide 7 · Justificativa técnica e trade-offs

```
Mantenha a comparação Serverless versus EC2 e o quadro de trade-off. Acrescente um segundo quadro no mesmo
estilo: "Alternativa considerada: API Gateway HTTP API, 70% mais barata. Escolhemos REST API pela validação
de payload no gateway (JSON Schema antes da Lambda), usage plans por cliente e WAF. Na escala atual a
diferença é de US$ 0,25 por mês."
```

## Slide 8 · Mapeamento de requisitos

```
Substitua a tabela por esta, com as mesmas três colunas (Requisito do Cliente, Serviço AWS, Recurso
Implementado), oito linhas:
Ingestão via API autenticada | API Gateway REST + Cognito | autorizador JWT, validador JSON Schema, throttling
Isolamento multi-tenant | Lambda + IAM + S3 | prefixo usuario-{id}/ vindo do token, imposto no código e na IAM role
Recuperação segura | Lambda + S3 | presigned URL de 5 min, 403 fora do prefixo, 25 MB por upload
Arquivamento de longo prazo | S3 Lifecycle | Deep Archive após 365 dias; versões antigas expiram em 730
Alta disponibilidade | Infraestrutura AWS | multi-AZ nativo em S3, Lambda, API Gateway e Cognito
Controle de custos | S3 Classes + Budgets | lifecycle automático, Budget com alerta em 50% e 100%
Observabilidade | CloudWatch + SNS | 4 alarmes, dashboard, e-mail
Reprodutibilidade | Terraform + GitHub Actions | um código, N ambientes, apply e destroy em 2 minutos
```

## Slide 9 · Escalabilidade e resiliência

```
Mantenha os três cartões. Acrescente um quarto, "E com 10× mais usuários?": "500 mil documentos por mês:
nenhum componente muda. Lambda escala a milhares de execuções; S3 não tem limite prático. O custo que
cresce é armazenamento e transferência; a mitigação é CloudFront ou cobrar egress do cliente." E uma
linha de rodapé: "Gargalo conhecido: concorrência da Lambda na conta (1.000 por padrão). Alarme de
throttling avisa; aumento é um ticket."
```

## Slide 10 · Segurança e isolamento

```
Reorganize o lado direito em três blocos com estes títulos e textos. "Identidade: Cognito para clientes;
IAM roles de mínimo privilégio para Lambda e pipeline; nenhuma chave de acesso de longa duração (OIDC)."
"Rede: sem VPC por decisão. Nenhum componente roda em rede privada; a superfície é o API Gateway com TLS,
throttling e WAF opcional." "Dados: criptografia SSE-S3, política que nega tráfego sem TLS, Block Public
Access, versioning, URLs assinadas que expiram em 5 minutos e limitam 25 MB, validação de tipo de arquivo."
Na pirâmide, acrescente no topo "Layer 0 — Cognito: o cliente não escolhe o próprio id, ele vem do token"
e, na camada 2, acrescente "+ validação de payload no gateway".
```

## Slide 11 · FinOps e retenção

```
Mantenha o gráfico. Substitua o bloco "Projeção para 50k docs/mês" por uma tabela pequena, título
"Custo mensal no mês 12 (us-east-1, 50 mil docs/mês, 12 MB cada)": S3 Standard 7.200 GB | US$ 165,60;
Transferência de saída 500 GB | US$ 45,00; API Gateway 100 mil req | US$ 0,35; Lambda, Cognito, CloudWatch |
US$ 0 (faixa gratuita); Total | ≈ US$ 211. Abaixo, em destaque: "99% do custo é armazenamento e
transferência; computação é centavos. Por isso otimizamos classe de armazenamento, não Lambda."
Troque "Estimativa de poupança: USD 150+/mês no ano 2" por "Economia com lifecycle: ≈ US$ 156/mês no ano 2
(US$ 331 → US$ 175)". Acrescente uma linha: "Estimativa oficial: AWS Pricing Calculator — [link]".
```

Depois: substitua `[link]` pelo link gerado no Calculator.

## Slide 12 · Resiliência e disponibilidade

```
Mantenha os dois quadros. Acrescente um terceiro no mesmo estilo, título "E se uma zona cair?":
"Nada visível para o cliente. S3, Lambda, API Gateway e Cognito são multi-AZ por padrão; não existe
instância para cair nem failover para acionar."
```

## Slide 13 · Proteção e recuperação de dados

```
Mantenha o quadro de Versioning. Substitua o quadro de RTO/RPO por uma tabela com colunas Cenário, RPO,
RTO e cinco linhas: Documento apagado ou sobrescrito por engano | 0 (versão anterior) | minutos;
Falha de uma zona de disponibilidade | 0 | 0, transparente; Perda da aplicação (Lambda, API, Cognito) |
0 | ≈ 2 min via terraform apply; Documento em Deep Archive | 0 | 12 h (Standard) ou 48 h (Bulk);
Falha regional | não coberto na Fase 1 | Fase 2: replicação entre regiões. Rodapé: "Procedimento de
restore documentado no RUNBOOK (aws s3api restore-object, Tier Bulk)."
```

## Slide 14 · IaC e roadmap

```
Mantenha os três blocos numerados. No bloco 1, acrescente ao final: "CI/CD no GitHub Actions: validação
e plan em cada PR; apply e destroy manuais com confirmação; autenticação OIDC, zero segredos no GitHub."
No bloco 2, acrescente: "Documentação técnica no repositório: README, RUNBOOK e 6 ADRs." No bloco 3,
após Textract e Bedrock, acrescente: "replicação entre regiões, Object Lock para retenção legal, usage
plans por cliente, CloudFront para downloads."
```

## Slide 15 · Demonstração prática

```
Substitua o conteúdo por três blocos lado a lado, cada um com título, uma linha de texto e um espaço
de imagem. Bloco 1 "Provisionamento": "terraform apply cria 33 recursos em 72 segundos; destroy em 16."
Bloco 2 "Evidências ao vivo": "10 verificações: upload assinado, download idêntico, 403 entre clientes,
401 sem token, 400 do validador, 404, limite de 25 MB, 403 na URL pública, lifecycle, alarmes."
Bloco 3 "Observabilidade": "Dashboard CloudWatch e quatro alarmes em OK durante a demo."
Rodapé: "Demo ao vivo: mise run smoke, console S3 e CloudWatch, aba Actions do GitHub."
```

Depois: arraste as três capturas do ensaio (apply, saída do smoke, dashboard).

## Slide 16 · Conclusão

```
Substitua os quatro cartões por: "Problema — crescer 600 GB por mês com isolamento total entre clientes e
uma equipe pequena." "Solução — serverless com isolamento por identidade, lifecycle automático e IaC."
"Benefícios — zero servidores, custo proporcional ao uso, −96% no arquivamento, evidências auditáveis."
"Próximos passos — Textract e Bedrock por eventos do S3, replicação entre regiões, usage plans por
cliente." Mantenha o quadro final de próximos passos, trocando o texto por: "Validação técnica com a
Startup XYZ · Aprovação do orçamento FinOps · Kick-off da Fase 2".
```
