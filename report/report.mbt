///|
/// Render a compact deterministic text summary suitable for terminals.
pub fn render_summary(message : @model.InternetMessage) -> String {
  let builder = StringBuilder()
  builder.write_string("MoonMIME message\n")
  builder.write_string("raw-bytes: " + message.stats.raw_bytes.to_string() + "\n")
  builder.write_string("entities: " + message.stats.entities.to_string() + "\n")
  builder.write_string("maximum-depth: " + message.stats.maximum_depth.to_string() + "\n")
  builder.write_string("diagnostics: " + message.diagnostics.length().to_string() + "\n")
  builder.write_string("\nPATH       KIND      MEDIA TYPE                    RAW BODY\n")
  for entity in @query.entities(message) {
    let path = render_path(entity.path)
    builder.write_string(pad_right(path, 11))
    builder.write_string(pad_right(kind_name(entity.kind), 10))
    builder.write_string(pad_right(entity.media_type.essence(), 30))
    builder.write_string(entity.body_range.length().to_string())
    match entity.filename() {
      Some(value) => builder.write_string("  filename=" + value)
      None => ()
    }
    builder.write_char('\n')
  }
  builder.to_string()
}

///|
/// Render stable JSON without requiring a platform-specific JSON runtime.
pub fn render_json(message : @model.InternetMessage) -> String {
  let builder = StringBuilder()
  builder.write_string("{\"schema\":\"moonmime.inspect.v1\",")
  builder.write_string("\"stats\":{")
  json_int(builder, "raw_bytes", message.stats.raw_bytes, false)
  json_int(builder, "entities", message.stats.entities, true)
  json_int(builder, "leaf_entities", message.stats.leaf_entities, true)
  json_int(builder, "multipart_entities", message.stats.multipart_entities, true)
  json_int(builder, "embedded_messages", message.stats.embedded_messages, true)
  json_int(builder, "maximum_depth", message.stats.maximum_depth, true)
  builder.write_string("},\"entities\":[")
  let all = @query.entities(message)
  for index in 0..<all.length() {
    if index > 0 { builder.write_char(',') }
    write_entity(builder, all[index])
  }
  builder.write_string("],\"attachments\":[")
  let attachments = @query.attachments(message)
  for index in 0..<attachments.length() {
    if index > 0 { builder.write_char(',') }
    write_attachment(builder, attachments[index])
  }
  builder.write_string("],\"diagnostics\":[")
  for index in 0..<message.diagnostics.length() {
    if index > 0 { builder.write_char(',') }
    write_diagnostic(builder, message.diagnostics[index])
  }
  builder.write_string("]}")
  builder.to_string()
}

///|
fn write_entity(builder : StringBuilder, entity : @model.MimeEntity) -> Unit {
  builder.write_string("{\"path\":")
  write_path(builder, entity.path)
  json_string(builder, "kind", kind_name(entity.kind), true)
  json_string(builder, "media_type", entity.media_type.essence(), true)
  json_string(builder, "transfer_encoding", entity.transfer_encoding.to_string(), true)
  json_int(builder, "entity_start", entity.entity_range.start, true)
  json_int(builder, "entity_end", entity.entity_range.end, true)
  json_int(builder, "body_start", entity.body_range.start, true)
  json_int(builder, "body_end", entity.body_range.end, true)
  builder.write_string(",\"filename\":")
  write_optional_string(builder, entity.filename())
  builder.write_string(",\"disposition\":")
  match entity.disposition {
    Some(value) => write_quoted(builder, value.kind)
    None => builder.write_string("null")
  }
  builder.write_char('}')
}

///|
fn write_attachment(builder : StringBuilder, attachment : @model.Attachment) -> Unit {
  builder.write_string("{\"path\":")
  write_path(builder, attachment.path)
  builder.write_string(",\"filename\":")
  write_optional_string(builder, attachment.filename)
  json_string(builder, "media_type", attachment.media_type, true)
  json_string(builder, "transfer_encoding", attachment.transfer_encoding, true)
  json_int(builder, "raw_size", attachment.raw_size, true)
  builder.write_string(",\"explicit\":")
  builder.write_string(if attachment.explicit { "true" } else { "false" })
  builder.write_char('}')
}

///|
fn write_diagnostic(builder : StringBuilder, diagnostic : @model.ParseDiagnostic) -> Unit {
  builder.write_string("{\"code\":")
  write_quoted(builder, diagnostic.code.to_code())
  json_string(builder, "message", diagnostic.message, true)
  json_int(builder, "start", diagnostic.range.start, true)
  json_int(builder, "end", diagnostic.range.end, true)
  builder.write_string(",\"entity_path\":")
  write_path(builder, diagnostic.entity_path)
  builder.write_char('}')
}

///|
fn kind_name(kind : @model.EntityKind) -> String {
  match kind {
    @model.Leaf => "leaf"
    @model.Multipart => "multipart"
    @model.EmbeddedMessage => "message"
  }
}

///|
fn render_path(path : Array[Int]) -> String {
  if path.is_empty() { return "." }
  let builder = StringBuilder()
  for index in 0..<path.length() {
    if index > 0 { builder.write_char('.') }
    builder.write_string(path[index].to_string())
  }
  builder.to_string()
}

///|
fn write_path(builder : StringBuilder, path : Array[Int]) -> Unit {
  builder.write_char('[')
  for index in 0..<path.length() {
    if index > 0 { builder.write_char(',') }
    builder.write_string(path[index].to_string())
  }
  builder.write_char(']')
}

///|
fn json_int(
  builder : StringBuilder,
  name : String,
  value : Int,
  comma : Bool,
) -> Unit {
  if comma { builder.write_char(',') }
  write_quoted(builder, name)
  builder.write_char(':')
  builder.write_string(value.to_string())
}

///|
fn json_string(
  builder : StringBuilder,
  name : String,
  value : String,
  comma : Bool,
) -> Unit {
  if comma { builder.write_char(',') }
  write_quoted(builder, name)
  builder.write_char(':')
  write_quoted(builder, value)
}

///|
fn write_optional_string(builder : StringBuilder, value : String?) -> Unit {
  match value {
    Some(value) => write_quoted(builder, value)
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
      b'"' => { builder.write_string("\\\""); cursor = cursor + 1 }
      b'\\' => { builder.write_string("\\\\"); cursor = cursor + 1 }
      b'\b' => { builder.write_string("\\b"); cursor = cursor + 1 }
      b'\t' => { builder.write_string("\\t"); cursor = cursor + 1 }
      b'\n' => { builder.write_string("\\n"); cursor = cursor + 1 }
      b'\r' => { builder.write_string("\\r"); cursor = cursor + 1 }
      _ => {
        if byte < b' ' {
          builder.write_string("\\u00" + hex_digit(byte.to_int() >> 4) + hex_digit(byte.to_int() & 15))
          cursor = cursor + 1
        } else {
          let width = utf8_width(byte)
          let text = @utf8.decode(bytes[cursor:cursor + width]) catch { _ => "�" }
          builder.write_string(text)
          cursor = cursor + width
        }
      }
    }
  }
  builder.write_char('"')
}

///|
fn hex_digit(value : Int) -> String {
  if value < 10 { value.to_string() } else { Int::unsafe_to_char('a'.to_int() + value - 10).to_string() }
}

///|
fn utf8_width(byte : Byte) -> Int {
  if byte < b'\x80' { 1 } else if byte < b'\xe0' { 2 } else if byte < b'\xf0' { 3 } else { 4 }
}

///|
fn pad_right(value : String, width : Int) -> String {
  let length = @utf8.encode(value).length()
  if length >= width { return value + " " }
  value + " ".repeat(width - length)
}
