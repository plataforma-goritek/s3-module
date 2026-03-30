check "kms_required_for_kms_algorithm" {
  assert {
    condition     = var.sse_algorithm != "aws:kms" || var.kms_key_id != null
    error_message = "kms_key_id e obrigatorio quando sse_algorithm = aws:kms."
  }
}

check "public_read_requires_public_access_disabled" {
  assert {
    condition     = !var.public_read_enabled || !var.public_access_enabled
    error_message = "Quando public_read_enabled = true, public_access_enabled deve ser false para nao bloquear a policy publica."
  }
}

check "public_policy_statements_valid" {
  assert {
    condition = alltrue([
      for s in var.public_policy_statements : (
        length(s.actions) > 0 &&
        length(s.resources) > 0 &&
        alltrue([for a in s.actions : trimspace(a) != ""]) &&
        alltrue([for r in s.resources : trimspace(r) != ""])
      )
    ])
    error_message = "Cada item de public_policy_statements deve conter actions/resources nao vazios."
  }
}

check "lifecycle_rules_have_action" {
  assert {
    condition = alltrue([
      for r in var.lifecycle_rules : (
        try(r.expiration_days, null) != null ||
        length(try(r.transitions, [])) > 0 ||
        try(r.noncurrent_version_expiration_days, null) != null ||
        length(try(r.noncurrent_version_transitions, [])) > 0
      )
    ])
    error_message = "Cada lifecycle_rule precisa definir ao menos uma acao: expiration_days, transitions, noncurrent_version_expiration_days ou noncurrent_version_transitions."
  }
}
