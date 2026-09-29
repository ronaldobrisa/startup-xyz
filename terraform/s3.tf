# Bucket de documentos: isolamento por prefixo usuario-{id}/, versioning, criptografia,
# Block Public Access e lifecycle para Glacier Deep Archive.

resource "aws_s3_bucket" "documents" {
  bucket        = "${local.name}-documents-${local.account_id}"
  force_destroy = var.force_destroy_bucket
}

resource "aws_s3_bucket_versioning" "documents" {
  bucket = aws_s3_bucket.documents.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "documents" {
  bucket = aws_s3_bucket.documents.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "documents" {
  bucket                  = aws_s3_bucket.documents.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "documents" {
  bucket = aws_s3_bucket.documents.id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

# RF "Arquivamento automatico": objetos com mais de N dias vao para Deep Archive.
# Versoes antigas seguem a mesma regra; uploads multipart abandonados sao limpos.
resource "aws_s3_bucket_lifecycle_configuration" "documents" {
  bucket = aws_s3_bucket.documents.id

  rule {
    id     = "arquivar-deep-archive-${var.archive_after_days}d"
    status = "Enabled"

    filter {
      prefix = "usuario-"
    }

    transition {
      days          = var.archive_after_days
      storage_class = "DEEP_ARCHIVE"
    }

    noncurrent_version_transition {
      noncurrent_days = var.archive_after_days
      storage_class   = "DEEP_ARCHIVE"
    }

    # Versoes antigas protegem contra exclusao/sobrescrita acidental, mas nao ficam para sempre
    # (cada versao em Deep Archive tem cobranca minima de 180 dias).
    noncurrent_version_expiration {
      noncurrent_days = var.noncurrent_version_expiration_days
    }

    # Remove marcadores de exclusao que ficaram sem versoes por baixo.
    expiration {
      expired_object_delete_marker = true
    }
  }

  rule {
    id     = "abortar-multipart-incompleto"
    status = "Enabled"

    filter {}

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }

  depends_on = [aws_s3_bucket_versioning.documents]
}

# Politica do bucket: so TLS, e so a role da Lambda toca em objetos (alem do root/admin da conta).
data "aws_iam_policy_document" "documents_bucket" {
  statement {
    sid     = "DenyInsecureTransport"
    effect  = "Deny"
    actions = ["s3:*"]
    resources = [
      aws_s3_bucket.documents.arn,
      "${aws_s3_bucket.documents.arn}/*",
    ]
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "documents" {
  bucket = aws_s3_bucket.documents.id
  policy = data.aws_iam_policy_document.documents_bucket.json

  depends_on = [aws_s3_bucket_public_access_block.documents]
}
