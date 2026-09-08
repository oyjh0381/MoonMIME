///|
/// Details retained from Quoted-Printable body decoding.
pub(all) struct QuotedPrintableResult {
  bytes : Bytes
  escaped_octets : Int
  soft_line_breaks : Int
  bare_lf_soft_breaks : Int
} derive(Debug, Eq)

///|
/// Decode RFC 2045 Quoted-Printable body content with bounded output.
///
/// Compatible mode additionally accepts the widespread `=LF` soft break and
/// reports how often it occurred. Invalid hexadecimal escapes and dangling
/// equals signs remain fatal in both modes.
pub fn decode_quoted_printable(
  input : Bytes,
  mode : @model.ParseMode,
  max_output : Int,
) -> QuotedPrintableResult raise @model.MimeError {
  validate_limit(max_output)
  let output : Array[Byte] = []
  let mut cursor = 0
  let mut escaped = 0
  let mut soft = 0
  let mut bare_lf = 0
  while cursor < input.length() {
    if input[cursor] != b'=' {
      push_bounded(output, input[cursor], max_output)
      cursor = cursor + 1
      continue
    }
    if cursor + 1 >= input.length() {
      raise @model.InvalidQuotedPrintable(cursor, "dangling equals sign")
    }
    if input[cursor + 1] == b'\r' {
      if cursor + 2 < input.length() && input[cursor + 2] == b'\n' {
        soft = soft + 1
        cursor = cursor + 3
        continue
      }
      raise @model.InvalidQuotedPrintable(
        cursor,
        "carriage return after equals is not followed by line feed",
      )
    }
    if input[cursor + 1] == b'\n' {
      if mode == @model.Strict {
        raise @model.InvalidQuotedPrintable(
          cursor,
          "bare LF soft break is not valid in strict mode",
        )
      }
      soft = soft + 1
      bare_lf = bare_lf + 1
      cursor = cursor + 2
      continue
    }
    if cursor + 2 >= input.length() {
      raise @model.InvalidQuotedPrintable(cursor, "incomplete hexadecimal escape")
    }
    let high = @bytesutil.hex_value(input[cursor + 1])
    let low = @bytesutil.hex_value(input[cursor + 2])
    match (high, low) {
      (Some(high), Some(low)) => {
        push_bounded(output, (high * 16 + low).to_byte(), max_output)
        escaped = escaped + 1
        cursor = cursor + 3
      }
      _ =>
        raise @model.InvalidQuotedPrintable(
          cursor,
          "equals sign must introduce two hexadecimal digits or a soft line break",
        )
    }
  }
  {
    bytes: Bytes::from_array(output),
    escaped_octets: escaped,
    soft_line_breaks: soft,
    bare_lf_soft_breaks: bare_lf,
  }
}

///|
/// Decode the Q encoding used inside an RFC 2047 encoded-word.
///
/// Unlike body Quoted-Printable, underscore represents ASCII space and soft
/// line breaks are not available inside one encoded-word.
pub fn decode_q_word(
  input : Bytes,
  max_output : Int,
) -> Bytes raise @model.MimeError {
  validate_limit(max_output)
  let output : Array[Byte] = []
  let mut cursor = 0
  while cursor < input.length() {
    match input[cursor] {
      b'_' => {
        push_bounded(output, b' ', max_output)
        cursor = cursor + 1
      }
      b'=' => {
        if cursor + 2 >= input.length() {
          raise @model.InvalidQuotedPrintable(cursor, "incomplete Q escape")
        }
        let high = @bytesutil.hex_value(input[cursor + 1])
        let low = @bytesutil.hex_value(input[cursor + 2])
        match (high, low) {
          (Some(high), Some(low)) => {
            push_bounded(output, (high * 16 + low).to_byte(), max_output)
            cursor = cursor + 3
          }
          _ =>
            raise @model.InvalidQuotedPrintable(
              cursor,
              "invalid hexadecimal Q escape",
            )
        }
      }
      b'?' =>
        raise @model.InvalidQuotedPrintable(
          cursor,
          "question mark must terminate the encoded-word before Q decoding",
        )
      byte => {
        if byte < b'!' || byte > b'~' {
          raise @model.InvalidQuotedPrintable(
            cursor,
            "Q encoded-text contains a non-printable literal",
          )
        }
        push_bounded(output, byte, max_output)
        cursor = cursor + 1
      }
    }
  }
  Bytes::from_array(output)
}

///|
fn validate_limit(limit : Int) -> Unit raise @model.MimeError {
  if limit <= 0 {
    raise @model.InvalidArgument("max_output must be greater than zero")
  }
}

///|
fn push_bounded(
  output : Array[Byte],
  value : Byte,
  limit : Int,
) -> Unit raise @model.MimeError {
  if output.length() >= limit {
    raise @model.DecodedOutputTooLarge(output.length() + 1, limit)
  }
  output.push(value)
}

