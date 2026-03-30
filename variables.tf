variable "name" {
  description = "Nome base do modulo para identificar recursos."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{1,61}[a-z0-9]$", var.name))
    error_message = "name deve conter apenas letras minusculas, numeros e hifen, com tamanho entre 3 e 63."
  }
}

variable "tags" {
  description = "Tags aplicadas aos recursos do modulo."
  type        = map(string)
  default     = {}
}

variable "deployment_mode" {
  description = "Perfil de deploy. Valores suportados: simple, production."
  type        = string
  default     = "simple"

  validation {
    condition     = contains(["simple", "production"], var.deployment_mode)
    error_message = "deployment_mode deve ser 'simple' ou 'production'."
  }
}

variable "bucket_name" {
  description = "Nome explicito do bucket. Quando null, usa o valor de name."
  type        = string
  default     = null
}

variable "server_side_encryption_enabled" {
  description = "Habilita criptografia em repouso no bucket."
  type        = bool
  default     = true
}

variable "sse_algorithm" {
  description = "Algoritmo de criptografia em repouso. Valores: AES256 ou aws:kms."
  type        = string
  default     = "AES256"

  validation {
    condition     = contains(["AES256", "aws:kms"], var.sse_algorithm)
    error_message = "sse_algorithm deve ser 'AES256' ou 'aws:kms'."
  }
}

variable "kms_key_id" {
  description = "ARN/ID da KMS Key quando sse_algorithm = aws:kms."
  type        = string
  default     = null
}

variable "versioning_enabled" {
  description = "Habilita versionamento do bucket."
  type        = bool
  default     = true
}

variable "object_ownership" {
  description = "Controle de ownership dos objetos."
  type        = string
  default     = "BucketOwnerPreferred"

  validation {
    condition = contains([
      "BucketOwnerPreferred",
      "ObjectWriter",
      "BucketOwnerEnforced"
    ], var.object_ownership)
    error_message = "object_ownership deve ser BucketOwnerPreferred, ObjectWriter ou BucketOwnerEnforced."
  }
}

variable "public_access_enabled" {
  description = "Controla se o Public Access Block fica habilitado."
  type        = bool
  default     = true
}

variable "public_read_enabled" {
  description = "Quando true, cria policy para permitir acesso publico de leitura."
  type        = bool
  default     = false
}

variable "public_policy_statements" {
  description = "Statements opcionais para customizar a bucket policy publica quando public_read_enabled = true."
  type = list(object({
    sid       = optional(string)
    effect    = optional(string, "Allow")
    actions   = list(string)
    resources = list(string)
    principals = optional(list(object({
      type        = string
      identifiers = list(string)
    })), [])
    conditions = optional(list(object({
      test     = string
      variable = string
      values   = list(string)
    })), [])
  }))
  default = []
}

variable "lifecycle_rules" {
  description = "Regras opcionais de lifecycle para expiracao e transicao."
  type = list(object({
    id      = string
    enabled = optional(bool, true)
    prefix  = optional(string)
    tags    = optional(map(string), {})

    expiration_days = optional(number)

    transitions = optional(list(object({
      days          = number
      storage_class = string
    })), [])

    noncurrent_version_expiration_days = optional(number)

    noncurrent_version_transitions = optional(list(object({
      days          = number
      storage_class = string
    })), [])
  }))
  default = []
}
