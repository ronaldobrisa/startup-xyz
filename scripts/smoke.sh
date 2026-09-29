#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
export MSYS_NO_PATHCONV=1

TF_DIR=terraform
OUT_DIR=.smoke
mkdir -p "$OUT_DIR"

jq() { command jq "$@" | tr -d '\r'; }
DISCARD="$OUT_DIR/discard"

API_URL=$(terraform -chdir="$TF_DIR" output -raw api_base_url)
BUCKET=$(terraform -chdir="$TF_DIR" output -raw documents_bucket)
POOL_ID=$(terraform -chdir="$TF_DIR" output -raw user_pool_id)
CLIENT_ID=$(terraform -chdir="$TF_DIR" output -raw user_pool_client_id)
REGION="${AWS_REGION:-us-east-1}"

USER_A=123
USER_B=456
FILENAME=contrato.pdf
PASSWORD="Demo-$(openssl rand -hex 6)-Aa1!"

pass=0; fail=0
ok()    { echo "  [OK]     $*"; pass=$((pass+1)); }
falha() { echo "  [FALHOU] $*"; fail=$((fail+1)); }
titulo(){ echo; echo "== $* =="; }

upload_post() {
  local resp="$1" file="$2" url args=()
  url=$(echo "$resp" | jq -r '.upload.url')
  while IFS=$'\t' read -r k v; do args+=(-F "$k=$v"); done < <(echo "$resp" | jq -r '.upload.fields | to_entries[] | "\(.key)\t\(.value)"')
  curl -sS -o "$OUT_DIR/upload-resp.xml" -w '%{http_code}' "${args[@]}" -F "file=@$file" "$url"
}

titulo "1. Usuarios no Cognito ($POOL_ID)"
for u in "$USER_A" "$USER_B"; do
  aws cognito-idp admin-create-user --region "$REGION" --user-pool-id "$POOL_ID" \
    --username "$u" --message-action SUPPRESS >/dev/null 2>&1 || true
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

titulo "2. Upload como usuario $USER_A via presigned POST"
printf '%%PDF-1.4\n%% Documento de teste da Startup XYZ - %s\n%%%%EOF\n' "$(date -u +%FT%TZ)" > "$OUT_DIR/$FILENAME"

RESP=$(curl -sS -X POST "$API_URL/documents" \
  -H "Authorization: $TOKEN_A" -H "Content-Type: application/json" \
  -d "{\"filename\":\"$FILENAME\",\"content_type\":\"application/pdf\"}")
echo "$RESP" | jq '{key, content_type, max_bytes, expires_in, campos_assinados: (.upload.fields | keys)}'
KEY=$(echo "$RESP" | jq -r '.key')
[ "$KEY" = "usuario-$USER_A/$FILENAME" ] && ok "key isolada no prefixo usuario-$USER_A/" || falha "key inesperada: $KEY"

CODE=$(upload_post "$RESP" "$OUT_DIR/$FILENAME")
[ "$CODE" = "204" ] && ok "POST no S3 -> $CODE" || { falha "POST no S3 -> $CODE"; cat "$OUT_DIR/upload-resp.xml"; echo; }

titulo "3. Download como usuario $USER_A (dono)"
RESP=$(curl -sS "$API_URL/documents/$KEY" -H "Authorization: $TOKEN_A")
DOWNLOAD_URL=$(echo "$RESP" | jq -r '.download_url // empty')
if [ -n "$DOWNLOAD_URL" ]; then
  curl -sS -o "$OUT_DIR/baixado.pdf" "$DOWNLOAD_URL"
  cmp -s "$OUT_DIR/$FILENAME" "$OUT_DIR/baixado.pdf" && ok "conteudo baixado identico ao enviado" || falha "conteudo divergente"
else
  falha "sem download_url: $RESP"
fi

titulo "4. Isolamento: usuario $USER_B tenta ler o documento do $USER_A"
CODE=$(curl -sS -o "$OUT_DIR/403.json" -w '%{http_code}' "$API_URL/documents/$KEY" -H "Authorization: $TOKEN_B")
cat "$OUT_DIR/403.json"; echo
[ "$CODE" = "403" ] && ok "HTTP $CODE (negado pelo prefixo)" || falha "esperado 403, veio $CODE"

titulo "5. API autenticada: requisicao sem token"
CODE=$(curl -sS -o "$DISCARD" -w '%{http_code}' "$API_URL/documents/$KEY")
[ "$CODE" = "401" ] && ok "HTTP $CODE sem Authorization" || falha "esperado 401, veio $CODE"

titulo "6. Validacao de payload no API Gateway (content_type fora do enum)"
CODE=$(curl -sS -o "$OUT_DIR/400.json" -w '%{http_code}' -X POST "$API_URL/documents" \
  -H "Authorization: $TOKEN_A" -H "Content-Type: application/json" \
  -d '{"filename":"virus.exe","content_type":"application/x-msdownload"}')
cat "$OUT_DIR/400.json"; echo
[ "$CODE" = "400" ] && ok "HTTP $CODE rejeitado antes da Lambda" || falha "esperado 400, veio $CODE"

titulo "7. Documento inexistente"
CODE=$(curl -sS -o "$DISCARD" -w '%{http_code}' "$API_URL/documents/usuario-$USER_A/nao-existe.pdf" -H "Authorization: $TOKEN_A")
[ "$CODE" = "404" ] && ok "HTTP $CODE" || falha "esperado 404, veio $CODE"

titulo "8. Limite de tamanho imposto pelo S3 (politica do presigned POST)"
MAX_BYTES=$(curl -sS -X POST "$API_URL/documents" -H "Authorization: $TOKEN_A" -H "Content-Type: application/json" \
  -d '{"filename":"grande.pdf","content_type":"application/pdf"}' | tee "$OUT_DIR/grande.json" | jq -r '.max_bytes')
head -c $((MAX_BYTES + 1024)) /dev/zero > "$OUT_DIR/grande.pdf"
CODE=$(upload_post "$(cat "$OUT_DIR/grande.json")" "$OUT_DIR/grande.pdf")
[ "$CODE" = "400" ] && ok "HTTP $CODE EntityTooLarge para $((MAX_BYTES / 1024 / 1024)) MB + 1 KB" || falha "esperado 400, veio $CODE"
rm -f "$OUT_DIR/grande.pdf"

titulo "9. Block Public Access: URL publica direta do S3"
CODE=$(curl -sS -o "$DISCARD" -w '%{http_code}' "https://$BUCKET.s3.$REGION.amazonaws.com/$KEY")
[ "$CODE" = "403" ] && ok "HTTP $CODE no acesso publico" || falha "esperado 403, veio $CODE"

titulo "10. Evidencias de configuracao"
echo "-- objetos em $BUCKET:"; aws s3 ls "s3://$BUCKET/" --recursive
echo "-- versioning:"; aws s3api get-bucket-versioning --bucket "$BUCKET" --output json | jq -c .
echo "-- block public access:"; aws s3api get-public-access-block --bucket "$BUCKET" --output json | jq -c .PublicAccessBlockConfiguration
echo "-- lifecycle:"; aws s3api get-bucket-lifecycle-configuration --bucket "$BUCKET" --output json \
  | jq -c '.Rules[] | {ID, Status, Prefix: .Filter.Prefix, Transitions, NoncurrentVersionTransitions, NoncurrentVersionExpiration}'
echo "-- alarmes:"; aws cloudwatch describe-alarms --region "$REGION" --alarm-name-prefix "$(terraform -chdir="$TF_DIR" output -raw lambda_function_name | sed 's/-api$//')" \
  --query 'MetricAlarms[].{alarme:AlarmName,estado:StateValue}' --output table
ok "evidencias coletadas"

echo
echo "RESULTADO: $pass verificacoes OK, $fail falhas"
[ "$fail" -eq 0 ]
