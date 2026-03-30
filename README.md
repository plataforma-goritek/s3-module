# S3 Terraform Module (Criptografia + Versioning + (Optional) Public Read)

## O que este módulo cria
- `aws_s3_bucket`
- `aws_s3_bucket_versioning`
- `aws_s3_bucket_server_side_encryption_configuration`
- `aws_s3_bucket_ownership_controls`
- `aws_s3_bucket_public_access_block`
- `aws_s3_bucket_policy` (quando necessário para `public_read_enabled=true`)
- `aws_s3_bucket_lifecycle_configuration` (opcional, quando `lifecycle_rules` é fornecido)

## Requisitos
- Terraform `>= 1.5.0`
- Provider AWS `>= 5.0`

## Qual problema este módulo resolve
Provisionar buckets S3 com um padrão de segurança consistente:
- criptografia em repouso por padrão
- versionamento por padrão
- controle explícito para habilitar acesso público somente quando necessário

## Descrição do projeto
Este projeto implementa um módulo Terraform reutilizável para criação de buckets S3 com foco em segurança por padrão e configuração previsível entre ambientes.

Ele foi desenhado para:
- padronizar a criação de buckets em diferentes serviços/projetos
- reduzir erros de configuração de segurança (encryption/versioning/public access)
- permitir evolução de regras (policy e lifecycle) sem duplicar código nos consumidores
- servir como bloco de infraestrutura que pode ser composto com outros módulos

## Input mínimo para funcionar
- `name`
- `public_access_enabled` (para controlar o `aws_s3_bucket_public_access_block`)
- `public_read_enabled` (para permitir leitura pública via policy, quando aplicável)

Recomendado:
- `server_side_encryption_enabled` (default `true`)
- `sse_algorithm` (default `"AES256"`)
- `versioning_enabled` (default `true`)

## Quais outputs o projeto consumidor realmente precisa
- `bucket_name`
- `bucket_arn`

## Como usar futuramente com outros módulos
Este módulo pode ser integrado em stacks maiores como peça de armazenamento compartilhada entre aplicações, pipelines e distribuição de conteúdo.

Padrões comuns de integração:
- **CloudFront/CDN**: usar `bucket_arn` para criar policy restrita ao distribution/OAC e servir arquivos estáticos.
- **ECS/Lambda**: usar `bucket_name` em variáveis de aplicação para upload/download de artefatos e arquivos de negócio.
- **Módulos de IAM**: criar políticas de least privilege referenciando `bucket_arn` e `bucket_arn/*`.
- **Módulos de observabilidade/governança**: aplicar regras de lifecycle para retenção e custo.

Fluxo recomendado de composição:
1. Instanciar o módulo `s3` na camada base de infraestrutura.
2. Exportar `bucket_name` e `bucket_arn` via outputs do ambiente raiz.
3. Consumir esses outputs nos módulos de aplicação (`ecs`, `lambda`, `cloudfront`, `iam`).
4. Evoluir acesso público e policy por variáveis (`public_read_enabled` e statements de policy), sem alterar o código dos consumidores.

Exemplo de integração em stack:

```hcl
module "s3_assets" {
  source = "git::https://github.com/your-org/s3-module.git?ref=v1.0.0"

  name                  = "assets-bucket"
  deployment_mode       = "production"
  public_access_enabled = false
  public_read_enabled   = false
}

module "app_iam" {
  source = "git::https://github.com/your-org/iam-module.git?ref=v1.0.0"

  s3_bucket_arn = module.s3_assets.bucket_arn
}

module "app_ecs" {
  source = "git::https://github.com/your-org/ecs-module.git?ref=v1.0.0"

  environment = {
    ASSETS_BUCKET = module.s3_assets.bucket_name
  }
}
```

## Modos de deploy suportados
- `simple`
- `production`

## Estrutura de arquivos recomendada
- `versions.tf`
- `variables.tf`
- `main.tf`
- `outputs.tf`
- `checks.tf` (quando houver regras entre variáveis)
- `README.md`
- `examples/simple/main.tf`
- `examples/production/main.tf` (opcional, mas recomendado)

## Contrato do módulo (interface)

### Inputs (padrão recomendado)
- `name`
- `tags`
- `deployment_mode`
- `bucket_name` (opcional: se `null`, o módulo gera a partir de `name`)

Criptografia em repouso:
- `server_side_encryption_enabled` (default `true`)
- `sse_algorithm` (enum: `"AES256"` ou `"aws:kms"`)
- `kms_key_id` (string/null; requerido quando `sse_algorithm="aws:kms"`)

Versionamento:
- `versioning_enabled` (default `true`)

Ownership:
- `object_ownership` (ex.: `"BucketOwnerPreferred"`)

Acesso público:
- `public_access_enabled` (bool; controla o `public access block`)
- `public_read_enabled` (bool; quando `true`, permite `s3:GetObject` para `*` via bucket policy)

Opcional:
- `lifecycle_rules` (lista/config para expiração/transition)

### Boas práticas
- Validar enums com `contains([...], var.sse_algorithm)`
- Validar dependências cruzadas:
  - se `sse_algorithm="aws:kms"`, então `kms_key_id` não pode ser `null`
  - se `public_read_enabled=true`, `public_access_enabled` deve permitir a política pública funcionar

## Segurança por padrão (checklist)
- Criptografia em repouso ligada por padrão (`server_side_encryption_enabled=true`)
- Versionamento ligado por padrão (`versioning_enabled=true`)
- ACLs evitadas; preferir policy + ownership controls
- Public read somente com flags explícitas

## Exemplo simples (bucket privado / sem public read)

```hcl
module "s3" {
  source = "git::https://github.com/your-org/s3-module.git?ref=v1.0.0"

  name = "my-bucket"
  deployment_mode = "simple"
  tags = {}

  server_side_encryption_enabled = true
  sse_algorithm = "AES256"
  versioning_enabled = true

  public_access_enabled = true
  public_read_enabled = false

  object_ownership = "BucketOwnerPreferred"
}
```