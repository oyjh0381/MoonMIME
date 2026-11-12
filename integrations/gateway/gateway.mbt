///|
/// Action returned to a mail ingestion pipeline.
#derive(Debug, Eq)
pub(all) enum GatewayAction {
  Allow
  Quarantine
}

///|
/// Explicit gateway policy. Parsing limits remain enforced independently.
#derive(Debug, Eq)
pub(all) struct GatewayPolicy {
  mode : @model.ParseMode
  quarantine_on : @audit.AuditSeverity
  limits : @model.ResourceLimits
}

///|
/// Stable, explainable result for one ingestion candidate.
#derive(Debug, Eq)
pub(all) struct GatewayDecision {
  source_id : String
  action : GatewayAction
  raw_bytes : Int32
  entity_count : Int32
  attachment_count : Int32
  triggered_codes : Array[String]
  audit : @audit.AuditReport
}

///|
/// Recommended policy for heterogeneous real-world mail: parse recoverable
/// deviations, preserve every diagnostic, and quarantine medium/high findings.
pub fn GatewayPolicy::recommended() -> GatewayPolicy {
  {
    mode: @model.Compatible,
    quarantine_on: @audit.Medium,
    limits: @model.ResourceLimits::secure_defaults(),
  }
}

///|
/// Apply MoonMIME as a reusable pre-ingestion gate.
///
/// The caller owns transport, storage, and the actual quarantine operation.
/// This function performs no file writes and does not decode attachments.
pub fn evaluate(
  input : Bytes,
  source_id : String,
  policy~ : GatewayPolicy = GatewayPolicy::recommended(),
) -> GatewayDecision raise @model.MimeError {
  let message = @parser.parse_message(
    input,
    mode=policy.mode,
    limits=policy.limits,
  )
  evaluate_parsed(message, source_id, policy)
}

///|
fn evaluate_parsed(
  message : @model.InternetMessage,
  source_id : String,
  policy : GatewayPolicy,
) -> GatewayDecision {
  let audit = @audit.audit_message(message)
  let triggered_codes : Array[String] = []
  for finding in audit.findings {
    if severity_rank(finding.severity) >= severity_rank(policy.quarantine_on) {
      let code = finding.code.to_code()
      if !contains(triggered_codes, code) {
        triggered_codes.push(code)
      }
    }
  }
  {
    source_id,
    action: if triggered_codes.is_empty() {
      Allow
    } else {
      Quarantine
    },
    raw_bytes: message.stats.raw_bytes,
    entity_count: message.stats.entities,
    attachment_count: @query.attachments(message).length(),
    triggered_codes,
    audit,
  }
}

///|
/// Render one decision as a JSON Lines-safe `moonmime.gateway.v1` record.
pub fn render_json(decision : GatewayDecision) -> String {
  let builder = StringBuilder()
  builder.write_string("{\"schema\":\"moonmime.gateway.v1\",\"source_id\":")
  write_quoted(builder, decision.source_id)
  builder.write_string(",\"action\":\"")
  builder.write_string(decision.action.to_string())
  builder.write_string("\",\"raw_bytes\":")
  builder.write_string(decision.raw_bytes.to_string())
  builder.write_string(",\"entity_count\":")
  builder.write_string(decision.entity_count.to_string())
  builder.write_string(",\"attachment_count\":")
  builder.write_string(decision.attachment_count.to_string())
  builder.write_string(",\"triggered_codes\":[")
  for index in 0..<decision.triggered_codes.length() {
    if index > 0 {
      builder.write_char(',')
    }
    write_quoted(builder, decision.triggered_codes[index])
  }
  builder.write_string("],\"audit\":")
  builder.write_string(@audit.render_json(decision.audit))
  builder.write_char('}')
  builder.to_string()
}

///|
/// Render a fail-closed input/parsing error without losing batch context.
pub fn render_error_json(source_id : String, error : String) -> String {
  let builder = StringBuilder()
  builder.write_string("{\"schema\":\"moonmime.gateway.v1\",\"source_id\":")
  write_quoted(builder, source_id)
  builder.write_string(",\"action\":\"reject\",\"error\":")
  write_quoted(builder, error)
  builder.write_char('}')
  builder.to_string()
}

///|
pub fn GatewayAction::to_string(self : GatewayAction) -> String {
  match self {
    Allow => "allow"
    Quarantine => "quarantine"
  }
}

///|
fn severity_rank(severity : @audit.AuditSeverity) -> Int32 {
  match severity {
    @audit.Info => 0
    @audit.Low => 1
    @audit.Medium => 2
    @audit.High => 3
  }
}

///|
fn contains(values : Array[String], wanted : String) -> Bool {
  for value in values {
    if value == wanted {
      return true
    }
  }
  false
}

///|
fn write_quoted(builder : StringBuilder, value : String) -> Unit {
  builder.write_char('"')
  let bytes = @utf8.encode(value)
  let mut cursor = 0
  while cursor < bytes.length() {
    let byte = bytes[cursor]
    match byte {
      b'"' => {
        builder.write_string("\\\"")
        cursor = cursor + 1
      }
      b'\\' => {
        builder.write_string("\\\\")
        cursor = cursor + 1
      }
      b'\n' => {
        builder.write_string("\\n")
        cursor = cursor + 1
      }
      b'\r' => {
        builder.write_string("\\r")
        cursor = cursor + 1
      }
      b'\t' => {
        builder.write_string("\\t")
        cursor = cursor + 1
      }
      _ =>
        if byte < b' ' {
          builder.write_string(
            "\\u00" + hex(byte.to_int() >> 4) + hex(byte.to_int() & 15),
          )
          cursor = cursor + 1
        } else {
          let width = utf8_width(byte)
          let text = @utf8.decode(bytes[cursor:cursor + width]) catch {
            _ => "�"
          }
          builder.write_string(text)
          cursor = cursor + width
        }
    }
  }
  builder.write_char('"')
}

///|
fn hex(value : Int32) -> String {
  if value < 10 {
    value.to_string()
  } else {
    Int32::unsafe_to_char('a'.to_int() + value - 10).to_string()
  }
}

///|
fn utf8_width(byte : Byte) -> Int32 {
  if byte < b'\x80' {
    1
  } else if byte < b'\xe0' {
    2
  } else if byte < b'\xf0' {
    3
  } else {
    4
  }
}

///|
pub extend GatewayAction with @debug.Debug::{to_repr}

///|
pub extend GatewayAction with Eq::{not_equal, equal}

///|
pub extend GatewayPolicy with @debug.Debug::{to_repr}

///|
pub extend GatewayPolicy with Eq::{not_equal, equal}

///|
pub extend GatewayDecision with @debug.Debug::{to_repr}

///|
pub extend GatewayDecision with Eq::{not_equal, equal}
