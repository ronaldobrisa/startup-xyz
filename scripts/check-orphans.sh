#!/usr/bin/env bash
set -euo pipefail

PROJECT="${PROJECT:-startup-xyz}"
ENV="${ENV:-demo}"
REGION="${AWS_REGION:-us-east-1}"
TENTATIVAS="${TENTATIVAS:-3}"
ESPERA="${ESPERA:-10}"

listar_arns_marcados() {
  aws resourcegroupstaggingapi get-resources --region "$REGION" \
    --tag-filters "Key=Project,Values=$PROJECT" "Key=Environment,Values=$ENV" \
    --query 'ResourceTagMappingList[].ResourceARN' --output text | tr -s '[:space:]' '\n' | sed '/^$/d'
}

recurso_existe() {
  local arn="$1" servico id
  servico=$(echo "$arn" | cut -d: -f3)
  id=${arn##*:}
  case "$servico" in
    cognito-idp)
      aws cognito-idp describe-user-pool --region "$REGION" --user-pool-id "${id#userpool/}" >/dev/null 2>&1 ;;
    s3)
      aws s3api head-bucket --bucket "$id" >/dev/null 2>&1 ;;
    lambda)
      aws lambda get-function --region "$REGION" --function-name "$id" >/dev/null 2>&1 ;;
    apigateway)
      aws apigateway get-rest-api --region "$REGION" --rest-api-id "$(echo "$arn" | sed 's#.*/restapis/##; s#/.*##')" >/dev/null 2>&1 ;;
    logs)
      [ -n "$(aws logs describe-log-groups --region "$REGION" --log-group-name-prefix "$id" \
        --query "logGroups[?logGroupName=='$id'].logGroupName" --output text)" ] ;;
    iam)
      aws iam get-role --role-name "${id#role/}" >/dev/null 2>&1 ;;
    cloudwatch)
      if [[ "$arn" == *:alarm:* ]]; then
        [ -n "$(aws cloudwatch describe-alarms --region "$REGION" --alarm-names "$id" --query 'MetricAlarms[].AlarmName' --output text)" ]
      else
        aws cloudwatch get-dashboard --region "$REGION" --dashboard-name "${id#dashboard/}" >/dev/null 2>&1
      fi ;;
    *)
      return 0 ;;
  esac
}

for i in $(seq 1 "$TENTATIVAS"); do
  SOBRAS=""
  while read -r arn; do
    [ -z "$arn" ] && continue
    if recurso_existe "$arn"; then
      SOBRAS+="$arn"$'\n'
    else
      echo "ignorado (indice da Tagging API atrasado, recurso ja excluido): $arn"
    fi
  done <<< "$(listar_arns_marcados)"

  if [ -z "$SOBRAS" ]; then
    echo "[OK] nenhum recurso com Project=$PROJECT Environment=$ENV em $REGION"
    exit 0
  fi

  if [ "$i" -lt "$TENTATIVAS" ]; then
    echo "tentativa $i/$TENTATIVAS: ainda ha $(printf '%s' "$SOBRAS" | grep -c .) recurso(s); aguardando ${ESPERA}s..."
    sleep "$ESPERA"
  fi
done

echo "[FALHOU] recursos remanescentes (Project=$PROJECT Environment=$ENV):"
printf '%s' "$SOBRAS" | sed 's/^/  - /'
exit 1
