///|
/// Copy a validated half-open range from immutable bytes.
pub fn slice(
  input : Bytes,
  start : Int,
  end : Int,
) -> Bytes raise @model.MimeError {
  if start < 0 || end < start || end > input.length() {
    raise @model.InvalidByteRange(start, end, input.length())
  }
  Bytes::from_array(input[start:end].to_array())
}

///|
/// Append a byte range to a mutable output without a temporary allocation.
pub fn append_range(
  output : Array[Byte],
  input : Bytes,
  start : Int,
  end : Int,
) -> Unit raise @model.MimeError {
  if start < 0 || end < start || end > input.length() {
    raise @model.InvalidByteRange(start, end, input.length())
  }
  for index in start..<end {
    output.push(input[index])
  }
}

///|
/// Compare a byte range with an ASCII string exactly.
pub fn equals_ascii(
  input : Bytes,
  start : Int,
  end : Int,
  expected : String,
) -> Bool {
  if start < 0 || end < start || end > input.length() {
    return false
  }
  let other = @utf8.encode(expected)
  if end - start != other.length() {
    return false
  }
  for index in 0..<other.length() {
    if input[start + index] != other[index] {
      return false
    }
  }
  true
}

///|
/// Compare a byte range with an ASCII string case-insensitively.
pub fn equals_ascii_ci(
  input : Bytes,
  start : Int,
  end : Int,
  expected : String,
) -> Bool {
  if start < 0 || end < start || end > input.length() {
    return false
  }
  let other = @utf8.encode(expected)
  if end - start != other.length() {
    return false
  }
  for index in 0..<other.length() {
    if lower_byte(input[start + index]) != lower_byte(other[index]) {
      return false
    }
  }
  true
}

///|
/// Whether `needle` occurs at `offset` without reading past `end`.
pub fn starts_with_at(
  input : Bytes,
  offset : Int,
  end : Int,
  needle : Bytes,
) -> Bool {
  if offset < 0 || end < offset || end > input.length() {
    return false
  }
  if needle.length() > end - offset {
    return false
  }
  for index in 0..<needle.length() {
    if input[offset + index] != needle[index] {
      return false
    }
  }
  true
}

///|
/// Find the first exact byte sequence in a bounded range.
pub fn find(input : Bytes, needle : Bytes, start : Int, end : Int) -> Int? {
  if start < 0 || end < start || end > input.length() || needle.is_empty() {
    return None
  }
  if needle.length() > end - start {
    return None
  }
  let last = end - needle.length()
  for offset in start..<=last {
    if starts_with_at(input, offset, end, needle) {
      return Some(offset)
    }
  }
  None
}

///|
/// Trim ASCII space and horizontal tab around a range.
pub fn trim_wsp(input : Bytes, start : Int, end : Int) -> (Int, Int) {
  let mut left = start
  let mut right = end
  while left < right && is_wsp(input[left]) {
    left = left + 1
  }
  while right > left && is_wsp(input[right - 1]) {
    right = right - 1
  }
  (left, right)
}

///|
/// Trim ASCII space, tab, CR, and LF around a range.
pub fn trim_ascii_space(input : Bytes, start : Int, end : Int) -> (Int, Int) {
  let mut left = start
  let mut right = end
  while left < right && is_ascii_space(input[left]) {
    left = left + 1
  }
  while right > left && is_ascii_space(input[right - 1]) {
    right = right - 1
  }
  (left, right)
}

///|
/// ASCII whitespace recognized by transfer encodings and value parsers.
pub fn is_ascii_space(value : Byte) -> Bool {
  value == b' ' || value == b'\t' || value == b'\r' || value == b'\n'
}

///|
/// Decode an ASCII byte range as UTF-8; non-ASCII or malformed input fails.
pub fn ascii_string(
  input : Bytes,
  start : Int,
  end : Int,
) -> String raise @model.MimeError {
  if start < 0 || end < start || end > input.length() {
    raise @model.InvalidByteRange(start, end, input.length())
  }
  for index in start..<end {
    if input[index] >= b'\x80' {
      raise @model.MalformedHeader(index, "expected ASCII bytes")
    }
  }
  @utf8.decode(input[start:end]) catch {
    _ => raise @model.MalformedHeader(start, "invalid ASCII range")
  }
}

///|
/// Losslessly map bytes 0..255 into Unicode code points U+0000..U+00FF.
pub fn latin1_string(input : Bytes) -> String {
  let output = StringBuilder(size_hint=input.length())
  for byte in input {
    output.write_char(byte.to_int().unsafe_to_char())
  }
  output.to_string()
}
