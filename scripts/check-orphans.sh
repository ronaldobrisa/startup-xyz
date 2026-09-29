#!/usr/bin/env bash
set -euo pipefail

PROJECT="${PROJECT:-startup-xyz}"
ENV="${ENV:-demo}"
REGION="${AWS_REGION:-us-east-1}"
TENTATIVAS="${TENTATIVAS:-4}"
ESPERA="${ESPERA:-10}"

for i in $(seq 1 "$TENTATIVAS"); do
  SOBRAS=$(aws resourcegroupstaggingapi get-resources --region "$REGION" \
    --tag-filters "Key=Project,Values=$PROJECT" "Key=Environment,Values=$ENV" \
    --query 'ResourceTagMappingList[].ResourceARN' --output text | tr -s '[:space:]' '\n' | sed '/^$/d')

  if [ -z "$SOBRAS" ]; then
    echo "[OK] nenhum recurso com Project=$PROJECT Environment=$ENV em $REGION"
    exit 0
  fi

  if [ "$i" -lt "$TENTATIVAS" ]; then
    echo "tentativa $i/$TENTATIVAS: ainda ha $(echo "$SOBRAS" | wc -l | tr -d ' ') recurso(s); aguardando ${ESPERA}s..."
    sleep "$ESPERA"
  fi
done

echo "[FALHOU] recursos remanescentes (Project=$PROJECT Environment=$ENV):"
echo "$SOBRAS" | sed 's/^/  - /'
exit 1
