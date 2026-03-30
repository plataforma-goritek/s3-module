locals {
  bucket_name_effective = coalesce(var.bucket_name, var.name)

  common_tags = merge(
    {
      Name       = local.bucket_name_effective
      Module     = "s3-module"
      ManagedBy  = "terraform"
      Deployment = var.deployment_mode
    },
    var.tags
  )

  public_policy_default_statements = [
    {
      sid       = "PublicReadGetObject"
      effect    = "Allow"
      actions   = ["s3:GetObject", "s3:GetObjectVersion"]
      resources = ["${aws_s3_bucket.this.arn}/*"]
      principals = [
        {
          type        = "AWS"
          identifiers = ["*"]
        }
      ]
      conditions = []
    },
    {
      sid       = "PublicReadListBucket"
      effect    = "Allow"
      actions   = ["s3:ListBucket"]
      resources = [aws_s3_bucket.this.arn]
      principals = [
        {
          type        = "AWS"
          identifiers = ["*"]
        }
      ]
      conditions = []
    }
  ]

  public_policy_statements_effective = length(var.public_policy_statements) > 0 ? var.public_policy_statements : tolist(local.public_policy_default_statements)
}

resource "aws_s3_bucket" "this" {
  bucket = local.bucket_name_effective
  tags   = local.common_tags
}

resource "aws_s3_bucket_versioning" "this" {
  bucket = aws_s3_bucket.this.id

  versioning_configuration {
    status = var.versioning_enabled ? "Enabled" : "Suspended"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  count  = var.server_side_encryption_enabled ? 1 : 0
  bucket = aws_s3_bucket.this.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = var.sse_algorithm
      kms_master_key_id = var.sse_algorithm == "aws:kms" ? var.kms_key_id : null
    }
  }
}

resource "aws_s3_bucket_ownership_controls" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    object_ownership = var.object_ownership
  }
}

resource "aws_s3_bucket_public_access_block" "this" {
  bucket = aws_s3_bucket.this.id

  block_public_acls       = var.public_access_enabled
  block_public_policy     = var.public_access_enabled
  ignore_public_acls      = var.public_access_enabled
  restrict_public_buckets = var.public_access_enabled
}

data "aws_iam_policy_document" "public_read" {
  count = var.public_read_enabled ? 1 : 0

  dynamic "statement" {
    for_each = local.public_policy_statements_effective

    content {
      sid       = try(statement.value.sid, null)
      effect    = try(statement.value.effect, "Allow")
      actions   = statement.value.actions
      resources = statement.value.resources

      dynamic "principals" {
        for_each = try(statement.value.principals, [])

        content {
          type        = principals.value.type
          identifiers = principals.value.identifiers
        }
      }

      dynamic "condition" {
        for_each = try(statement.value.conditions, [])

        content {
          test     = condition.value.test
          variable = condition.value.variable
          values   = condition.value.values
        }
      }
    }
  }
}

resource "aws_s3_bucket_policy" "public_read" {
  count  = var.public_read_enabled ? 1 : 0
  bucket = aws_s3_bucket.this.id
  policy = data.aws_iam_policy_document.public_read[0].json
}

resource "aws_s3_bucket_lifecycle_configuration" "this" {
  count  = length(var.lifecycle_rules) > 0 ? 1 : 0
  bucket = aws_s3_bucket.this.id

  dynamic "rule" {
    for_each = var.lifecycle_rules

    content {
      id     = rule.value.id
      status = try(rule.value.enabled, true) ? "Enabled" : "Disabled"

      filter {
        dynamic "and" {
          for_each = (try(rule.value.prefix, null) != null || length(try(rule.value.tags, {})) > 0) ? [1] : []

          content {
            prefix = try(rule.value.prefix, null)
            tags   = try(rule.value.tags, {})
          }
        }
      }

      dynamic "expiration" {
        for_each = try(rule.value.expiration_days, null) != null ? [rule.value.expiration_days] : []

        content {
          days = expiration.value
        }
      }

      dynamic "transition" {
        for_each = try(rule.value.transitions, [])

        content {
          days          = transition.value.days
          storage_class = transition.value.storage_class
        }
      }

      dynamic "noncurrent_version_expiration" {
        for_each = try(rule.value.noncurrent_version_expiration_days, null) != null ? [rule.value.noncurrent_version_expiration_days] : []

        content {
          noncurrent_days = noncurrent_version_expiration.value
        }
      }

      dynamic "noncurrent_version_transition" {
        for_each = try(rule.value.noncurrent_version_transitions, [])

        content {
          noncurrent_days = noncurrent_version_transition.value.days
          storage_class   = noncurrent_version_transition.value.storage_class
        }
      }
    }
  }
}
