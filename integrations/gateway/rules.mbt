///|
/// Application policy on declared metadata, not content sniffing or antivirus.
#derive(Eq, Debug)
pub(all) struct GatewayRules {
  allowed_media_types : Array[String]?
  blocked_media_types : Array[String]
  blocked_filename_suffixes : Array[String]
  max_attachments : Int32
  max_attachment_wire_bytes : Int32
  max_total_attachment_wire_bytes : Int32
  require_attachment_names : Bool
  quarantine_on_recovery : Bool
}

///|
pub fn GatewayRules::default() -> GatewayRules {
  {
    allowed_media_types: None,
    blocked_media_types: [],
    blocked_filename_suffixes: [],
    max_attachments: 128,
    max_attachment_wire_bytes: 16 * 1024 * 1024,
    max_total_attachment_wire_bytes: 32 * 1024 * 1024,
    require_attachment_names: false,
    quarantine_on_recovery: false,
  }
}

///|
#derive(Eq, Debug)
pub(all) struct PolicyFinding {
  code : String
  entity_path : Array[Int32]
  evidence_range : @model.ByteRange
}

///|
#derive(Eq, Debug)
pub(all) struct GatewayAssessment {
  decision : GatewayDecision
  policy_findings : Array[PolicyFinding]
}

///|
fn validate_rules(rules : GatewayRules) -> Unit raise @model.MimeError {
  if rules.max_attachments < 0 ||
    rules.max_attachments > 10000 ||
    rules.max_attachment_wire_bytes < 0 ||
    rules.max_total_attachment_wire_bytes < 0 {
    raise @model.InvalidArgument("invalid attachment policy limits")
  }
  let groups = [
    rules.blocked_media_types,
    rules.allowed_media_types.unwrap_or([]),
  ]
  for group in groups {
    if group.length() > 64 {
      raise @model.InvalidArgument("at most 64 media types per rule")
    }
    for item in group {
      if item.length() > 128 ||
        item.split("/").count() != 2 ||
        item.has_prefix("/") ||
        item.has_suffix("/") {
        raise @model.InvalidArgument("expected exact lowercase media type")
      }
      for ch in item {
        if !(ch >= 'a' && ch <= 'z') &&
          !(ch >= '0' && ch <= '9') &&
          !['/', '+', '-', '.', '_'].contains(ch) {
          raise @model.InvalidArgument("expected exact lowercase media type")
        }
      }
    }
  }
  if rules.blocked_filename_suffixes.length() > 64 {
    raise @model.InvalidArgument("at most 64 filename suffixes")
  }
  for suffix in rules.blocked_filename_suffixes {
    if suffix.length() < 2 || suffix.length() > 32 || !suffix.has_prefix(".") {
      raise @model.InvalidArgument(
        "expected lowercase filename suffix starting with dot",
      )
    }
    for ch in suffix {
      if !(ch >= 'a' && ch <= 'z') && !(ch >= '0' && ch <= '9') && ch != '.' {
        raise @model.InvalidArgument("expected lowercase filename suffix")
      }
    }
  }
}

///|
pub fn evaluate_with_rules(
  input : Bytes,
  source_id : String,
  rules : GatewayRules,
  policy~ : GatewayPolicy = GatewayPolicy::recommended(),
) -> GatewayAssessment raise @model.MimeError {
  validate_rules(rules)
  let message = @parser.parse_message(
    input,
    mode=policy.mode,
    limits=policy.limits,
  )
  let base = evaluate_parsed(message, source_id, policy)
  let findings : Array[PolicyFinding] = []
  let attachments = @query.attachments(message)
  if attachments.length() > rules.max_attachments {
    findings.push({
      code: "attachment-count-limit",
      entity_path: [],
      evidence_range: message.root.entity_range,
    })
  }
  if rules.quarantine_on_recovery && !message.diagnostics.is_empty() {
    findings.push({
      code: "parser-recovery-policy",
      entity_path: [],
      evidence_range: message.root.entity_range,
    })
  }
  let mut total = 0L
  for candidate in attachments {
    let entity = @query.find_entity(message, candidate.path).unwrap()
    let add = fn(code : String) {
      findings.push({
        code,
        entity_path: candidate.path.copy(),
        evidence_range: entity.entity_range,
      })
    }
    if rules.blocked_media_types.contains(candidate.media_type) {
      add("blocked-declared-media-type")
    }
    if rules.allowed_media_types is Some(allowed) {
      if !allowed.contains(candidate.media_type) {
        add("undeclared-allowlist-media-type")
      }
    }
    match candidate.filename {
      None =>
        if rules.require_attachment_names {
          add("attachment-name-required")
        }
      Some(name) => {
        if rules.require_attachment_names && name.trim().is_empty() {
          add("attachment-name-required")
        }
        let lower = name.to_lower()
        if rules.blocked_filename_suffixes.any(suffix => {
            lower.has_suffix(suffix)
          }) {
          add("blocked-filename-suffix")
        }
      }
    }
    let size = entity.body_range.length()
    total += size.to_int64()
    if size > rules.max_attachment_wire_bytes {
      add("attachment-wire-size-limit")
    }
  }
  if total > rules.max_total_attachment_wire_bytes.to_int64() {
    findings.push({
      code: "attachment-total-wire-size-limit",
      entity_path: [],
      evidence_range: message.root.entity_range,
    })
  }
  {
    decision: {
      ..base,
      action: if findings.is_empty() {
        base.action
      } else {
        Quarantine
      },
    },
    policy_findings: findings,
  }
}

///|
pub fn assessment_json(result : GatewayAssessment) -> String {
  let findings : Array[Json] = result.policy_findings.map(item => {
    "code": Json::string(item.code),
    "entity_path": Json::array(
      item.entity_path.map(i => Json::number(i.to_double())),
    ),
    "start": Json::number(item.evidence_range.start.to_double()),
    "end": Json::number(item.evidence_range.end.to_double()),
  })
  "{\"schema\":\"moonmime.policy.v1\",\"decision\":" +
  render_json(result.decision) +
  ",\"policy_findings\":" +
  Json::array(findings).stringify() +
  "}"
}

///|
pub extend GatewayRules with Eq::{not_equal, equal}

///|
pub extend GatewayRules with @debug.Debug::{to_repr}

///|
pub extend PolicyFinding with Eq::{not_equal, equal}

///|
pub extend PolicyFinding with @debug.Debug::{to_repr}

///|
pub extend GatewayAssessment with Eq::{not_equal, equal}

///|
pub extend GatewayAssessment with @debug.Debug::{to_repr}
