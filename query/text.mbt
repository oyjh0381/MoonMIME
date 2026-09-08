///|
/// Decode the first Subject field's RFC 2047 encoded-words.
pub fn subject(
  message : @model.InternetMessage,
  mode? : @model.ParseMode = @model.Strict,
  max_output_bytes? : Int = 256 * 1024,
) -> String? raise @model.MimeError {
  match message.root.headers.first("subject") {
    None => None
    Some(field) =>
      Some(
        @header.decode_encoded_words(field.value, mode, max_output_bytes).value,
      )
  }
}

///|
/// Select and decode a preferred display body.
///
/// Non-attachment `text/plain` leaves are preferred over `text/html`; traversal
/// order breaks ties. This intentionally returns text only and never writes an
/// attachment filename to the filesystem.
pub fn preferred_text(
  message : @model.InternetMessage,
  mode? : @model.ParseMode = @model.Strict,
  max_output_bytes? : Int = 16 * 1024 * 1024,
) -> @model.TextSelection? raise @model.MimeError {
  let mut plain : @model.MimeEntity? = None
  let mut html : @model.MimeEntity? = None
  for entity in entities(message) {
    if entity.kind != @model.Leaf || entity.is_explicit_attachment() {
      continue
    }
    match entity.media_type.essence() {
      "text/plain" => if plain is None { plain = Some(entity) }
      "text/html" => if html is None { html = Some(entity) }
      _ => ()
    }
  }
  let selected = match plain {
    Some(value) => Some(value)
    None => html
  }
  match selected {
    None => None
    Some(entity) => {
      let decoded = @transfer.decode_entity_body(
        message,
        entity,
        mode,
        max_output=max_output_bytes,
      )
      let charset = entity.media_type.parameter("charset")
      Some({
        path: entity.path.copy(),
        media_type: entity.media_type.essence(),
        charset,
        text: decode_text_charset(decoded.bytes, charset),
      })
    }
  }
}

///|
fn decode_text_charset(
  input : Bytes,
  charset : String?,
) -> String raise @model.MimeError {
  let normalized = match charset {
    Some(value) => @bytesutil.lower_string(value)
    None => "us-ascii"
  }
  match normalized {
    "utf-8" | "utf8" =>
      @utf8.decode(input) catch {
        _ => raise @model.UnsupportedCharset("malformed utf-8")
      }
    "us-ascii" | "ascii" => {
      for byte in input {
        if byte >= b'\x80' {
          raise @model.UnsupportedCharset(
            "us-ascii body contains a non-ASCII octet",
          )
        }
      }
      @utf8.decode(input) catch {
        _ => raise @model.UnsupportedCharset("malformed us-ascii")
      }
    }
    "iso-8859-1" | "latin1" | "latin-1" => @bytesutil.latin1_string(input)
    unsupported => raise @model.UnsupportedCharset(unsupported)
  }
}
