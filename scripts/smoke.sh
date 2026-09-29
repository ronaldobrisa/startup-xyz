#!/usr/bin/env bash
# Prova ao vivo da arquitetura (slide "Demonstracao Pratica & Evidencias de Implantacao"):
#   1. cria dois usuarios no Cognito (123 e 456) e obtem tokens
#   2. usuario 123 pede presigned URL e faz upload de um PDF
#   3. usuario 123 recupera o proprio documento
#   4. usuario 456 tenta ler o documento do 123 -> 403 (isolamento multi-tenant)
#   5. sem token -> 401 (API autenticada)
#   6. URL publica do S3 -> 403 (Block Public Access)
#   7. mostra versioning, Block Public Access e lifecycle do bucket
#
# Requisitos: terraform (outputs do ambiente ja aplicado), aws cli, curl, jq, openssl.
set -euo pipefail

cd "$(dirname "$0")/.."
export MSYS_NO_PATHCONV=1  # Git Bash no Windows: nao converter "/documents" em caminho

TF_DIR=terraform
OUT_DIR=.smoke
mkdir -p "$OUT_DIR"

API_URL=$(terraform -chdir="$TF_DIR" output -raw api_base_url)
BUCKET=$(terraform -chdir="$TF_DIR" output -raw documents_bucket)
POOL_ID=$(terraform -chdir="$TF_DIR" output -raw user_pool_id)
CLIENT_ID=$(terraform -chdir="$TF_DIR" output -raw user_pool_client_id)
REGION="${AWS_REGION:-us-east-1}"

USER_A=123
USER_B=456
FILENAME=contrato.pdf
# Senha forte gerada por execucao; nunca impressa.
PASSWORD="Demo-$(openssl rand -hex 6)-Aa1!"

pass=0; fail=0
ok()   { echo "  [OK]     $*"; pass=$((pass+1)); }
falha(){ echo "  [FALHOU] $*"; fail=$((fail+1)); }
titulo(){ echo; echo "== $* =="; }

# ---------------------------------------------------------------------------
titulo "1. Usuarios no Cognito ($POOL_ID)"
for u in "$USER_A" "$USER_B"; do
  aws cognito-idp admin-create-user --region "$REGION" --user-pool-id "$POOL_ID" \
    --username "$u" --message-action SUPPRESS >/dev/null 2>&1 || true   # idempotente
  aws cognito-idp admin-set-user-password --region "$REGION" --user-pool-id "$POOL_ID" \
    --username "$u" --password "$PASSWORD" --permanent
  ok "usuario $u criado com senha permanente"
done

token_de() {
  aws cognito-idp initiate-auth --region "$REGION" --client-id "$CLIENT_ID" \
    --auth-flow USER_PASSWORD_AUTH \
    --auth-parameters "USERNAME=$1,PASSWORD=$PASSWORD" \
    --query 'AuthenticationResult.IdToken' --output text
}
TOKEN_A=$(token_de "$USER_A")
TOKEN_B=$(token_de "$USER_B")
ok "ID tokens obtidos (claim cognito:username = $USER_A / $USER_B)"

# ---------------------------------------------------------------------------
titulo "2. Upload como usuario $USER_A via presigned URL"
printf '%%PDF-1.4\n%% Documento de teste da Startup XYZ - %s\n%%%%EOF\n' "$(date -u +%FT%TZ)" > "$OUT_DIR/$FILENAME"

RESP=$(curl -sS -X POST "$API_URL/documents" \
  -H "Authorization: $TOKEN_A" -H "Content-Type: application/json" \
  -d "{\"filename\":\"$FILENAME\",\"content_type\":\"application/pdf\"}")
echo "$RESP" | jq '{key, method, expires_in}'
KEY=$(echo "$RESP" | jq -r '.key')
UPLOAD_URL=$(echo "$RESP" | jq -r '.upload_url')
[ "$KEY" = "usuario-$USER_A/$FILENAME" ] && ok "key isolada no prefixo usuario-$USER_A/" || falha "key inesperada: $KEY"

CODE=$(curl -sS -o /dev/null -w '%{http_code}' -X PUT "$UPLOAD_URL" \
  -H "Content-Type: application/pdf" --data-binary "@$OUT_DIR/$FILENAME")
[ "$CODE" = "200" ] && ok "PUT na presigned URL -> $CODE" || falha "PUT na presigned URL -> $CODE"

# ---------------------------------------------------------------------------
titulo "3. Download como usuario $USER_A (dono)"
RESP=$(curl -sS "$API_URL/documents/$KEY" -H "Authorization: $TOKEN_A")
DOWNLOAD_URL=$(echo "$RESP" | jq -r '.download_url // empty')
if [ -n "$DOWNLOAD_URL" ]; then
  curl -sS -o "$OUT_DIR/baixado.pdf" "$DOWNLOAD_URL"
  cmp -s "$OUT_DIR/$FILENAME" "$OUT_DIR/baixado.pdf" && ok "conteudo baixado identico ao enviado" || falha "conteudo divergente"
else
  falha "sem download_url: $RESP"
fi

# ---------------------------------------------------------------------------
titulo "4. Isolamento: usuario $USER_B tenta ler o documento do $USER_A"
CODE=$(curl -sS -o "$OUT_DIR/403.json" -w '%{http_code}' "$API_URL/documents/$KEY" -H "Authorization: $TOKEN_B")
cat "$OUT_DIR/403.json"; echo
[ "$CODE" = "403" ] && ok "HTTP $CODE (negado pelo prefixo)" || falha "esperado 403, veio $CODE"

# ---------------------------------------------------------------------------
titulo "5. API autenticada: requisicao sem token"
CODE=$(curl -sS -o /dev/null -w '%{http_code}' "$API_URL/documents/$KEY")
[ "$CODE" = "401" ] && ok "HTTP $CODE sem Authorization" || falha "esperado 401, veio $CODE"

# ---------------------------------------------------------------------------
titulo "6. Block Public Access: URL publica direta do S3"
CODE=$(curl -sS -o /dev/null -w '%{http_code}' "https://$BUCKET.s3.$REGION.amazonaws.com/$KEY")
[ "$CODE" = "403" ] && ok "HTTP $CODE no acesso publico" || falha "esperado 403, veio $CODE"

# ---------------------------------------------------------------------------
titulo "7. Configuracao do bucket $BUCKET"
echo "-- objetos:"; aws s3 ls "s3://$BUCKET/" --recursive
echo "-- versioning:"; aws s3api get-bucket-versioning --bucket "$BUCKET" --output json | jq -c .
echo "-- block public access:"; aws s3api get-public-access-block --bucket "$BUCKET" --output json | jq -c .PublicAccessBlockConfiguration
echo "-- lifecycle:"; aws s3api get-bucket-lifecycle-configuration --bucket "$BUCKET" --output json \
  | jq -c '.Rules[] | {ID, Status, Prefix: .Filter.Prefix, Transitions, NoncurrentVersionTransitions}'
ok "evidencias coletadas"

# ---------------------------------------------------------------------------
echo
echo "RESULTADO: $pass verificacoes OK, $fail falhas"
[ "$fail" -eq 0 ]
