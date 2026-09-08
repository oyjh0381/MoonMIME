///|
/// Resolve RFC 2231 extended and continued parameters into one value per name.
///
/// Extended values take precedence over plain values. Distinct parameter names
/// retain first-appearance order, while repeated plain values use the final
/// occurrence to match common MIME implementation behavior.
pub fn resolve_parameters(
  parameters : Array[@model.MediaParameter],
  mode : @model.ParseMode,
) -> Array[@model.MediaParameter] raise @model.MimeError {
  let output : Array[@model.MediaParameter] = []
  let seen : Array[String] = []
  for parameter in parameters {
    if seen.contains(parameter.lower_name) {
      continue
    }
    seen.push(parameter.lower_name)
    output.push(resolve_one(parameters, parameter.lower_name, mode))
  }
  output
}

///|
/// Resolve all parameters attached to a media type.
pub fn resolve_media_type(
  media : @model.MediaType,
  mode : @model.ParseMode,
) -> @model.MediaType raise @model.MimeError {
  { ..media, parameters: resolve_parameters(media.parameters, mode) }
}

///|
/// Resolve all parameters attached to Content-Disposition.
pub fn resolve_disposition(
  disposition : @model.ContentDisposition,
  mode : @model.ParseMode,
) -> @model.ContentDisposition raise @model.MimeError {
  { ..disposition, parameters: resolve_parameters(disposition.parameters, mode) }
}

///|
fn resolve_one(
  parameters : Array[@model.MediaParameter],
  name : String,
  mode : @model.ParseMode,
) -> @model.MediaParameter raise @model.MimeError {
  let matching : Array[@model.MediaParameter] = []
  for parameter in parameters {
    if parameter.lower_name == name {
      matching.push(parameter)
    }
  }
  let continuations : Array[@model.MediaParameter] = []
  let singles : Array[@model.MediaParameter] = []
  let plains : Array[@model.MediaParameter] = []
  for parameter in matching {
    match parameter.section {
      Some(_) => continuations.push(parameter)
      None => {
        if parameter.encoded {
          singles.push(parameter)
        } else {
          plains.push(parameter)
        }
      }
    }
  }
  if !continuations.is_empty() {
    let value = decode_continuations(continuations, mode)
    return resolved_parameter(name, value, true)
  }
  if !singles.is_empty() {
    let selected = singles[singles.length() - 1]
    let value = decode_initial_extended(selected.value)
    return resolved_parameter(name, value, true)
  }
  let selected = plains[plains.length() - 1]
  resolved_parameter(name, selected.value, false)
}

///|
fn resolved_parameter(
  name : String,
  value : String,
  extended : Bool,
) -> @model.MediaParameter {
  {
    name,
    lower_name: name,
    value,
    extended,
    section: None,
    encoded: false,
  }
}

///|
fn decode_continuations(
  pieces : Array[@model.MediaParameter],
  mode : @model.ParseMode,
) -> String raise @model.MimeError {
  let ordered : Array[@model.MediaParameter] = []
  let mut section = 0
  while true {
    let matches : Array[@model.MediaParameter] = []
    for piece in pieces {
      if piece.section == Some(section) {
        matches.push(piece)
      }
    }
    if matches.is_empty() {
      break
    }
    if matches.length() > 1 && mode == @model.Strict {
      raise @model.InvalidParameter("duplicate continuation section \{section}")
    }
    ordered.push(matches[matches.length() - 1])
    section = section + 1
  }
  if ordered.is_empty() {
    raise @model.InvalidParameter("parameter continuation does not start at section zero")
  }
  if ordered.length() != pieces.length() && mode == @model.Strict {
    raise @model.InvalidParameter("parameter continuation contains a gap or duplicate")
  }
  let output : Array[Byte] = []
  let mut charset : String? = None
  for index in 0..<ordered.length() {
    let piece = ordered[index]
    if index == 0 && piece.encoded {
      let initial = split_initial_extended(piece.value)
      charset = Some(initial.0)
      append_percent_decoded(output, initial.2)
    } else if piece.encoded {
      append_percent_decoded(output, piece.value)
    } else {
      let bytes = @utf8.encode(piece.value)
      for byte in bytes {
        output.push(byte)
      }
    }
  }
  match charset {
    Some(charset) => decode_charset(Bytes::from_array(output), charset)
    None =>
      @utf8.decode(Bytes::from_array(output)) catch {
        _ => @bytesutil.latin1_string(Bytes::from_array(output))
      }
  }
}

///|
fn decode_initial_extended(value : String) -> String raise @model.MimeError {
  let (charset, _language, encoded) = split_initial_extended(value)
  let output : Array[Byte] = []
  append_percent_decoded(output, encoded)
  decode_charset(Bytes::from_array(output), charset)
}

///|
fn split_initial_extended(
  value : String,
) -> (String, String, String) raise @model.MimeError {
  let bytes = @utf8.encode(value)
  let mut first = -1
  let mut second = -1
  for index in 0..<bytes.length() {
    if bytes[index] == b'\'' {
      if first < 0 {
        first = index
      } else {
        second = index
        break
      }
    }
  }
  if first <= 0 || second < 0 {
    raise @model.InvalidParameter(
      "extended value must use charset'language'value syntax",
    )
  }
  let charset = @utf8.decode(bytes[0:first]) catch {
    _ => raise @model.InvalidParameter("extended charset is not ASCII")
  }
  let language = @utf8.decode(bytes[first + 1:second]) catch {
    _ => raise @model.InvalidParameter("extended language is not ASCII")
  }
  let encoded = @utf8.decode(bytes[second + 1:]) catch {
    _ => raise @model.InvalidParameter("extended value is not ASCII")
  }
  (charset, language, encoded)
}

///|
fn append_percent_decoded(
  output : Array[Byte],
  value : String,
) -> Unit raise @model.MimeError {
  let bytes = @utf8.encode(value)
  let mut cursor = 0
  while cursor < bytes.length() {
    if bytes[cursor] != b'%' {
      output.push(bytes[cursor])
      cursor = cursor + 1
      continue
    }
    if cursor + 2 >= bytes.length() {
      raise @model.InvalidParameter("incomplete percent escape")
    }
    match (
      @bytesutil.hex_value(bytes[cursor + 1]),
      @bytesutil.hex_value(bytes[cursor + 2]),
    ) {
      (Some(high), Some(low)) => {
        output.push((high * 16 + low).to_byte())
        cursor = cursor + 3
      }
      _ => raise @model.InvalidParameter("invalid percent escape")
    }
  }
}

///|
fn decode_charset(input : Bytes, charset : String) -> String raise @model.MimeError {
  let normalized = @bytesutil.lower_string(charset)
  match normalized {
    "utf-8" | "utf8" =>
      @utf8.decode(input) catch {
        _ => raise @model.InvalidParameter("extended UTF-8 value is malformed")
      }
    "us-ascii" | "ascii" => {
      for byte in input {
        if byte >= b'\x80' {
          raise @model.InvalidParameter("extended US-ASCII value contains non-ASCII byte")
        }
      }
      @utf8.decode(input) catch {
        _ => raise @model.InvalidParameter("extended US-ASCII value is malformed")
      }
    }
    "iso-8859-1" | "latin1" | "latin-1" => @bytesutil.latin1_string(input)
    unsupported => raise @model.UnsupportedCharset(unsupported)
  }
}
