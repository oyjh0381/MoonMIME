///|
/// Whether a byte is an ASCII space or horizontal tab.
pub fn is_wsp(value : Byte) -> Bool {
  value == b' ' || value == b'\t'
}

///|
/// Whether a byte is an ASCII decimal digit.
pub fn is_digit(value : Byte) -> Bool {
  value >= b'0' && value <= b'9'
}

///|
/// Whether a byte is an ASCII alphabetic character.
pub fn is_alpha(value : Byte) -> Bool {
  (value >= b'A' && value <= b'Z') || (value >= b'a' && value <= b'z')
}

///|
/// Whether a byte is permitted in an RFC-style token.
pub fn is_token(value : Byte) -> Bool {
  if value <= b' ' || value >= b'\x7f' {
    return false
  }
  match value {
    b'('
    | b')'
    | b'<'
    | b'>'
    | b'@'
    | b','
    | b';'
    | b':'
    | b'\\'
    | b'"'
    | b'/'
    | b'['
    | b']'
    | b'?'
    | b'='
    | b'{'
    | b'}' => false
    _ => true
  }
}

///|
/// Whether a byte is a valid visible ASCII header-name character.
pub fn is_field_name(value : Byte) -> Bool {
  value >= b'!' && value <= b'~' && value != b':'
}

///|
/// Lowercase one ASCII byte, leaving all non-uppercase bytes unchanged.
pub fn lower_byte(value : Byte) -> Byte {
  if value >= b'A' && value <= b'Z' {
    (value.to_int() + 32).to_byte()
  } else {
    value
  }
}

///|
/// Lowercase an ASCII-compatible string without locale-sensitive behavior.
pub fn lower_string(value : String) -> String {
  let input = @utf8.encode(value)
  let output : Array[Byte] = []
  for byte in input {
    output.push(lower_byte(byte))
  }
  @utf8.decode(Bytes::from_array(output)) catch {
    _ => value
  }
}

///|
/// Parse one ASCII hexadecimal nibble.
pub fn hex_value(value : Byte) -> Int? {
  if value >= b'0' && value <= b'9' {
    Some(value.to_int() - b'0'.to_int())
  } else if value >= b'A' && value <= b'F' {
    Some(value.to_int() - b'A'.to_int() + 10)
  } else if value >= b'a' && value <= b'f' {
    Some(value.to_int() - b'a'.to_int() + 10)
  } else {
    None
  }
}

///|
/// Render one byte as two lower-case hexadecimal digits.
pub fn byte_hex(value : Byte) -> String {
  let digits = "0123456789abcdef"
  let number = value.to_int()
  "\{digits[number / 16]}\{digits[number % 16]}"
}

///|
/// Render bytes as lower-case hexadecimal text.
pub fn to_hex(input : Bytes) -> String {
  let buffer = StringBuilder(size_hint=input.length() * 2)
  for byte in input {
    buffer.write_string(byte_hex(byte))
  }
  buffer.to_string()
}
