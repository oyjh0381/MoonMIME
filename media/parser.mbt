///|
priv struct ValueCursor {
  bytes : Bytes
  mut offset : Int
  end : Int
}

///|
/// Parse a Content-Type field value into normalized media semantics.
pub fn parse_media_type(
  value : String,
  mode : @model.ParseMode,
  max_parameters : Int,
) -> @model.MediaType raise @model.MimeError {
  let cursor = new_cursor(value)
  skip_wsp(cursor)
  let top_level = parse_token(cursor, "media top-level type")
  skip_wsp(cursor)
  if !consume(cursor, b'/') {
    raise @model.InvalidMediaType("expected '/' between media type and subtype")
  }
  skip_wsp(cursor)
  let subtype = parse_token(cursor, "media subtype")
  let parameters = parse_parameters(cursor, mode, max_parameters, true)
  {
    top_level: @bytesutil.lower_string(top_level),
    subtype: @bytesutil.lower_string(subtype),
    parameters,
  }
}

///|
/// Parse Content-Disposition while preserving ordered extension parameters.
pub fn parse_content_disposition(
  value : String,
  mode : @model.ParseMode,
  max_parameters : Int,
) -> @model.ContentDisposition raise @model.MimeError {
  let cursor = new_cursor(value)
  skip_wsp(cursor)
  let kind = parse_token(cursor, "disposition type")
  let parameters = parse_parameters(cursor, mode, max_parameters, false)
  { kind: @bytesutil.lower_string(kind), parameters, }
}

///|
/// Parse the Content-Transfer-Encoding token.
pub fn parse_transfer_encoding(value : String) -> @model.TransferEncoding {
  let bytes = @utf8.encode(value)
  let (start, end) = @bytesutil.trim_ascii_space(bytes, 0, bytes.length())
  let normalized = @bytesutil.lower_string(
    @utf8.decode(bytes[start:end]) catch {
      _ => value
    },
  )
  match normalized {
    "7bit" | "" => @model.SevenBit
    "8bit" => @model.EightBit
    "binary" => @model.Binary
    "base64" => @model.Base64
    "quoted-printable" => @model.QuotedPrintable
    extension => @model.Extension(extension)
  }
}

///|
fn new_cursor(value : String) -> ValueCursor {
  let bytes = @utf8.encode(value)
  { bytes, offset: 0, end: bytes.length(), }
}

///|
fn parse_parameters(
  cursor : ValueCursor,
  mode : @model.ParseMode,
  max_parameters : Int,
  media_error : Bool,
) -> Array[@model.MediaParameter] raise @model.MimeError {
  if max_parameters <= 0 {
    raise @model.InvalidArgument("max_parameters must be greater than zero")
  }
  let parameters : Array[@model.MediaParameter] = []
  while true {
    skip_wsp(cursor)
    if cursor.offset >= cursor.end {
      break
    }
    if !consume(cursor, b';') {
      fail_parameterized(media_error, "unexpected data after primary token")
    }
    skip_wsp(cursor)
    if cursor.offset >= cursor.end {
      if mode == @model.Compatible {
        break
      }
      fail_parameterized(media_error, "trailing semicolon has no parameter")
    }
    if parameters.length() >= max_parameters {
      raise @model.InvalidArgument(
        "parameter count exceeds configured limit \{max_parameters}",
      )
    }
    let raw_name = parse_token(cursor, "parameter name")
    skip_wsp(cursor)
    if !consume(cursor, b'=') {
      fail_parameterized(media_error, "parameter has no equals sign")
    }
    skip_wsp(cursor)
    let parameter_value = if peek(cursor) == Some(b'"') {
      parse_quoted_string(cursor, media_error)
    } else {
      parse_token(cursor, "parameter value")
    }
    let (base_name, section, encoded, extended) = classify_parameter_name(
      raw_name,
    )
    parameters.push({
      name: raw_name,
      lower_name: @bytesutil.lower_string(base_name),
      value: parameter_value,
      extended,
      section,
      encoded,
    })
    skip_wsp(cursor)
    if cursor.offset < cursor.end && cursor.bytes[cursor.offset] != b';' {
      if mode == @model.Compatible {
        while cursor.offset < cursor.end && cursor.bytes[cursor.offset] != b';' {
          cursor.offset = cursor.offset + 1
        }
      } else {
        fail_parameterized(media_error, "unexpected data after parameter value")
      }
    }
  }
  parameters
}

///|
fn parse_token(
  cursor : ValueCursor,
  label : String,
) -> String raise @model.MimeError {
  let start = cursor.offset
  while cursor.offset < cursor.end &&
        @bytesutil.is_token(cursor.bytes[cursor.offset]) {
    cursor.offset = cursor.offset + 1
  }
  if cursor.offset == start {
    raise @model.InvalidMediaType("expected " + label)
  }
  @utf8.decode(cursor.bytes[start:cursor.offset]) catch {
    _ => raise @model.InvalidMediaType(label + " is not valid ASCII")
  }
}

///|
fn parse_quoted_string(
  cursor : ValueCursor,
  media_error : Bool,
) -> String raise @model.MimeError {
  ignore(consume(cursor, b'"'))
  let output : Array[Byte] = []
  while cursor.offset < cursor.end {
    let byte = cursor.bytes[cursor.offset]
    cursor.offset = cursor.offset + 1
    match byte {
      b'"' =>
        return @utf8.decode(Bytes::from_array(output)) catch {
          _ => @bytesutil.latin1_string(Bytes::from_array(output))
        }
      b'\\' => {
        if cursor.offset >= cursor.end {
          fail_parameterized(media_error, "quoted string ends after escape")
        }
        let escaped = cursor.bytes[cursor.offset]
        if escaped == b'\r' || escaped == b'\n' {
          fail_parameterized(
            media_error, "quoted-pair cannot escape a line ending",
          )
        }
        output.push(escaped)
        cursor.offset = cursor.offset + 1
      }
      b'\r' | b'\n' =>
        fail_parameterized(media_error, "line ending inside quoted parameter")
      value => output.push(value)
    }
  }
  fail_parameterized(media_error, "unterminated quoted parameter")
  ""
}

///|
fn classify_parameter_name(name : String) -> (String, Int?, Bool, Bool) {
  let bytes = @utf8.encode(name)
  let mut star = -1
  for index in 0..<bytes.length() {
    if bytes[index] == b'*' {
      star = index
      break
    }
  }
  if star < 0 {
    return (name, None, false, false)
  }
  let base = @utf8.decode(bytes[0:star]) catch { _ => name }
  if star == bytes.length() - 1 {
    return (base, None, true, true)
  }
  let mut cursor = star + 1
  let mut section = 0
  let mut digits = 0
  while cursor < bytes.length() && @bytesutil.is_digit(bytes[cursor]) {
    section = section * 10 + bytes[cursor].to_int() - b'0'.to_int()
    digits = digits + 1
    cursor = cursor + 1
  }
  if digits == 0 {
    return (name, None, false, false)
  }
  if cursor == bytes.length() {
    return (base, Some(section), false, true)
  }
  if cursor + 1 == bytes.length() && bytes[cursor] == b'*' {
    return (base, Some(section), true, true)
  }
  (name, None, false, false)
}

///|
fn skip_wsp(cursor : ValueCursor) -> Unit {
  while cursor.offset < cursor.end &&
        @bytesutil.is_wsp(cursor.bytes[cursor.offset]) {
    cursor.offset = cursor.offset + 1
  }
}

///|
fn peek(cursor : ValueCursor) -> Byte? {
  if cursor.offset < cursor.end {
    Some(cursor.bytes[cursor.offset])
  } else {
    None
  }
}

///|
fn consume(cursor : ValueCursor, expected : Byte) -> Bool {
  if cursor.offset < cursor.end && cursor.bytes[cursor.offset] == expected {
    cursor.offset = cursor.offset + 1
    true
  } else {
    false
  }
}

///|
fn fail_parameterized(
  media_error : Bool,
  message : String,
) -> Unit raise @model.MimeError {
  if media_error {
    raise @model.InvalidMediaType(message)
  } else {
    raise @model.InvalidDisposition(message)
  }
}
