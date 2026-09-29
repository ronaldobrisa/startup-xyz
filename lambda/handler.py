"""API de documentos da Startup XYZ.

Uma unica funcao atras do API Gateway (autorizador Cognito):

    POST /documents          body: {"filename": "...", "content_type": "application/pdf"}
                             -> 201 {"key", "upload_url", "expires_in"}
    GET  /documents/{key+}   -> 200 {"key", "download_url", "expires_in"}
                             -> 403 se a key nao estiver no prefixo do usuario autenticado

O id do tenant vem do claim ``cognito:username`` do ID token, ja validado pelo API Gateway.
O prefixo ``usuario-{id}/`` e aplicado no codigo E na politica IAM da role (defesa em profundidade).
Sem dependencias externas: boto3 ja vem no runtime.
"""

from __future__ import annotations

import json
import logging
import os
import re
from typing import Any
from urllib.parse import unquote

import boto3
from botocore.config import Config
from botocore.exceptions import ClientError

BUCKET = os.environ["BUCKET_NAME"]
URL_TTL = int(os.environ.get("URL_TTL_SECONDS", "300"))

logger = logging.getLogger()
logger.setLevel(logging.INFO)

s3 = boto3.client("s3", config=Config(signature_version="s3v4"))

FILENAME_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$")
ALLOWED_CONTENT_TYPES = {"application/pdf", "image/png", "image/jpeg"}


def _response(status: int, body: dict[str, Any]) -> dict[str, Any]:
    return {
        "statusCode": status,
        "headers": {"Content-Type": "application/json; charset=utf-8"},
        "body": json.dumps(body, ensure_ascii=False),
    }


def _tenant_prefix(event: dict[str, Any]) -> str | None:
    claims = (event.get("requestContext") or {}).get("authorizer", {}).get("claims") or {}
    username = claims.get("cognito:username")
    if not username or not FILENAME_RE.match(username):
        return None
    return f"usuario-{username}/"


def lambda_handler(event: dict[str, Any], _context: Any) -> dict[str, Any]:
    prefix = _tenant_prefix(event)
    if prefix is None:
        return _response(401, {"erro": "token sem identidade de usuario"})

    method = event.get("httpMethod")
    resource = event.get("resource")
    logger.info({"acao": "request", "method": method, "resource": resource, "tenant": prefix})

    if method == "POST" and resource == "/documents":
        return _create_upload_url(event, prefix)
    if method == "GET" and resource == "/documents/{key+}":
        return _create_download_url(event, prefix)
    return _response(404, {"erro": "rota nao encontrada"})


def _create_upload_url(event: dict[str, Any], prefix: str) -> dict[str, Any]:
    try:
        body = json.loads(event.get("body") or "{}")
    except ValueError:
        return _response(400, {"erro": "body deve ser JSON"})

    filename = str(body.get("filename", ""))
    content_type = str(body.get("content_type", "application/pdf"))

    if not FILENAME_RE.match(filename):
        return _response(400, {"erro": "filename invalido (letras, numeros, ponto, hifen, underscore)"})
    if content_type not in ALLOWED_CONTENT_TYPES:
        return _response(400, {"erro": f"content_type deve ser um de {sorted(ALLOWED_CONTENT_TYPES)}"})

    key = f"{prefix}{filename}"
    url = s3.generate_presigned_url(
        "put_object",
        Params={"Bucket": BUCKET, "Key": key, "ContentType": content_type},
        ExpiresIn=URL_TTL,
    )
    logger.info({"acao": "upload_url", "key": key})
    return _response(
        201,
        {
            "key": key,
            "upload_url": url,
            "method": "PUT",
            "headers": {"Content-Type": content_type},
            "expires_in": URL_TTL,
        },
    )


def _create_download_url(event: dict[str, Any], prefix: str) -> dict[str, Any]:
    raw_key = (event.get("pathParameters") or {}).get("key", "")
    key = unquote(raw_key)

    # Isolamento multi-tenant: a key precisa comecar com o prefixo do usuario autenticado.
    if ".." in key or not key.startswith(prefix):
        logger.warning({"acao": "acesso_negado", "tenant": prefix, "key": key})
        return _response(403, {"erro": "acesso negado: documento fora do espaco do usuario"})

    try:
        s3.head_object(Bucket=BUCKET, Key=key)
    except ClientError as exc:
        code = exc.response.get("Error", {}).get("Code")
        if code in ("404", "NoSuchKey", "NotFound"):
            return _response(404, {"erro": "documento nao encontrado"})
        raise

    url = s3.generate_presigned_url(
        "get_object",
        Params={"Bucket": BUCKET, "Key": key},
        ExpiresIn=URL_TTL,
    )
    logger.info({"acao": "download_url", "key": key})
    return _response(200, {"key": key, "download_url": url, "expires_in": URL_TTL})
