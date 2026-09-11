///|
/// One attachment-like entity bound to its original encoded body bytes.
pub(all) struct EvidenceAttachment {
  entity_path : Array[Int]
  filename : String?
  media_type : String
  body_start : Int
  body_end : Int
  encoded_sha256 : String
} derive(Debug, Eq)

///|
/// Deterministic sidecar for a preserved `.eml` evidence item.
///
/// Acquisition timestamps, examiner identity, signatures, and evidence-store
/// locations deliberately remain the responsibility of the case system.
pub(all) struct EvidenceManifest {
  case_id : String
  source_id : String
  raw_sha256 : String
  raw_bytes : Int
  message_id : String?
  subject : String?
  entity_count : Int
  attachments : Array[EvidenceAttachment]
  audit : @audit.AuditReport
} derive(Debug, Eq)

///|
/// Build a byte-bound forensic sidecar without mutating or extracting evidence.
pub fn build_manifest(
  input : Bytes,
  case_id : String,
  source_id : String,
  limits? : @model.ResourceLimits = @model.ResourceLimits::secure_defaults(),
) -> EvidenceManifest raise @model.MimeError {
  require_identifier(case_id, "case_id")
  require_identifier(source_id, "source_id")
  let message = @parser.parse_message(input, mode=@model.Compatible, limits~)
  let attachments : Array[EvidenceAttachment] = []
  for candidate in @query.attachments(message) {
    match @query.find_entity(message, candidate.path) {
      Some(entity) => {
        let encoded = input[entity.body_range.start:entity.body_range.end].to_owned()
        attachments.push({
          entity_path: candidate.path.copy(),
          filename: candidate.filename,
          media_type: candidate.media_type,
          body_start: entity.body_range.start,
          body_end: entity.body_range.end,
          encoded_sha256: @sha256.digest_hex(encoded),
        })
      }
      None => ()
    }
  }
  {
    case_id,
    source_id,
    raw_sha256: @sha256.digest_hex(input),
    raw_bytes: input.length(),
    message_id: header_value(message.root.headers, "message-id"),
    subject: header_value(message.root.headers, "subject"),
    entity_count: message.stats.entities,
    attachments,
    audit: @audit.audit_message(message),
  }
}

///|
/// Render a stable `moonmime.forensics.v1` JSON sidecar.
pub fn render_json(manifest : EvidenceManifest) -> String {
  let builder = StringBuilder()
  builder.write_string("{\"schema\":\"moonmime.forensics.v1\",\"case_id\":")
  write_quoted(builder, manifest.case_id)
  builder.write_string(",\"source_id\":")
  write_quoted(builder, manifest.source_id)
  builder.write_string(",\"raw_sha256\":\"")
  builder.write_string(manifest.raw_sha256)
  builder.write_string("\",\"raw_bytes\":")
  builder.write_string(manifest.raw_bytes.to_string())
  builder.write_string(",\"message_id\":")
  write_optional(builder, manifest.message_id)
  builder.write_string(",\"subject\":")
  write_optional(builder, manifest.subject)
  builder.write_string(",\"entity_count\":")
  builder.write_string(manifest.entity_count.to_string())
  builder.write_string(",\"attachments\":[")
  for index in 0..<manifest.attachments.length() {
    if index > 0 {
      builder.write_char(',')
    }
    write_attachment(builder, manifest.attachments[index])
  }
  builder.write_string("],\"audit\":")
  builder.write_string(@audit.render_json(manifest.audit))
  builder.write_char('}')
  builder.to_string()
}

///|
fn header_value(headers : @model.HeaderBlock, name : StringView) -> String? {
  match headers.first(name) {
    Some(field) => Some(field.value)
    None => None
  }
}

///|
fn require_identifier(
  value : String,
  name : String,
) -> Unit raise @model.MimeError {
  if value.trim().is_empty() {
    raise @model.InvalidArgument(name + " must not be empty")
  }
  if @utf8.encode(value).length() > 1024 {
    raise @model.InvalidArgument(name + " exceeds 1024 UTF-8 bytes")
  }
}

///|
fn write_attachment(builder : StringBuilder, item : EvidenceAttachment) -> Unit {
  builder.write_string("{\"entity_path\":[")
  for index in 0..<item.entity_path.length() {
    if index > 0 {
      builder.write_char(',')
    }
    builder.write_string(item.entity_path[index].to_string())
  }
  builder.write_string("],\"filename\":")
  write_optional(builder, item.filename)
  builder.write_string(",\"media_type\":")
  write_quoted(builder, item.media_type)
  builder.write_string(",\"body_start\":")
  builder.write_string(item.body_start.to_string())
  builder.write_string(",\"body_end\":")
  builder.write_string(item.body_end.to_string())
  builder.write_string(",\"encoded_sha256\":\"")
  builder.write_string(item.encoded_sha256)
  builder.write_string("\"}")
}

///|
fn write_optional(builder : StringBuilder, value : String?) -> Unit {
  match value {
    Some(text) => write_quoted(builder, text)
    None => builder.write_string("null")
  }
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
fn hex(value : Int) -> String {
  if value < 10 {
    value.to_string()
  } else {
    Int::unsafe_to_char('a'.to_int() + value - 10).to_string()
  }
}

///|
fn utf8_width(byte : Byte) -> Int {
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
