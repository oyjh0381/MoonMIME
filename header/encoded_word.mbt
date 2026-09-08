///|
/// Result of decoding RFC 2047 encoded-words in one unstructured header value.
pub(all) struct EncodedHeaderResult {
  value : String
  decoded_words : Int
  preserved_invalid_words : Int
} derive(Debug, Eq)

///|
priv struct WordDecode {
  value : String
  end : Int
}

///|
/// Decode RFC 2047 encoded-words while preserving ordinary UTF-8 text.
///
/// Whitespace occurring only between two adjacent encoded-words is suppressed
/// as required by RFC 2047. Strict mode rejects a malformed `=?` candidate;
/// compatible mode copies it literally and records that preservation.
pub fn decode_encoded_words(
  input : String,
  mode : @model.ParseMode,
  max_output_bytes : Int,
) -> EncodedHeaderResult raise @model.MimeError {
  if max_output_bytes <= 0 {
    raise @model.InvalidArgument("max_output_bytes must be greater than zero")
  }
  let bytes = @utf8.encode(input)
  let builder = StringBuilder()
  let mut output_bytes = 0
  let mut decoded = 0
  let mut invalid = 0
  let mut cursor = 0
  let mut previous_was_word = false
  while cursor < bytes.length() {
    if starts_word(bytes, cursor) {
      let parsed : WordDecode? = try_decode_word(bytes, cursor) catch {
        error => {
          if mode == @model.Strict {
            raise error
          }
          invalid = invalid + 1
          None
        }
      }
      match parsed {
        Some(word) => {
          output_bytes = append_bounded(
            builder,
            word.value,
            output_bytes,
            max_output_bytes,
          )
          decoded = decoded + 1
          cursor = word.end
          previous_was_word = true
          continue
        }
        None => ()
      }
    }
    if previous_was_word && is_linear_whitespace(bytes[cursor]) {
      let whitespace_start = cursor
      while cursor < bytes.length() && is_linear_whitespace(bytes[cursor]) {
        cursor = cursor + 1
      }
      if cursor < bytes.length() && starts_word(bytes, cursor) {
        let lookahead : WordDecode? = try_decode_word(bytes, cursor) catch {
          _ => None
        }
        match lookahead {
          Some(_) => continue
          None => ()
        }
      }
      let text = @utf8.decode(bytes[whitespace_start:cursor]) catch {
        _ => raise @model.InvalidEncodedWord("header whitespace is not UTF-8")
      }
      output_bytes = append_bounded(builder, text, output_bytes, max_output_bytes)
      previous_was_word = false
      continue
    }
    let next = cursor + utf8_width(bytes[cursor])
    if next > bytes.length() {
      raise @model.InvalidEncodedWord("truncated UTF-8 header value")
    }
    let text = @utf8.decode(bytes[cursor:next]) catch {
      _ => raise @model.InvalidEncodedWord("header value is not valid UTF-8")
    }
    output_bytes = append_bounded(builder, text, output_bytes, max_output_bytes)
    cursor = next
    previous_was_word = false
  }
  { value: builder.to_string(), decoded_words: decoded, preserved_invalid_words: invalid }
}

///|
fn try_decode_word(input : Bytes, start : Int) -> WordDecode? raise @model.MimeError {
  if !starts_word(input, start) {
    return None
  }
  let charset_end = find_byte(input, b'?', start + 2)
  if charset_end is None || charset_end.unwrap() == start + 2 {
    raise @model.InvalidEncodedWord("encoded-word has no charset")
  }
  let encoding_start = charset_end.unwrap() + 1
  let encoding_end = find_byte(input, b'?', encoding_start)
  if encoding_end is None || encoding_end.unwrap() == encoding_start {
    raise @model.InvalidEncodedWord("encoded-word has no encoding token")
  }
  let text_start = encoding_end.unwrap() + 1
  let mut end = -1
  let mut cursor = text_start
  while cursor + 1 < input.length() {
    if input[cursor] == b'?' && input[cursor + 1] == b'=' {
      end = cursor
      break
    }
    cursor = cursor + 1
  }
  if end < 0 {
    raise @model.InvalidEncodedWord("encoded-word has no terminating ?=")
  }
  if end == text_start {
    raise @model.InvalidEncodedWord("encoded-word contains empty encoded-text")
  }
  for index in text_start..<end {
    if input[index] <= b' ' || input[index] >= b'\x7f' {
      raise @model.InvalidEncodedWord("encoded-text must contain printable ASCII without spaces")
    }
  }
  let charset = @utf8.decode(input[start + 2:charset_end.unwrap()]) catch {
    _ => raise @model.InvalidEncodedWord("charset token is not ASCII")
  }
  let encoding = @bytesutil.lower_string(
    @utf8.decode(input[encoding_start:encoding_end.unwrap()]) catch {
      _ => raise @model.InvalidEncodedWord("encoding token is not ASCII")
    },
  )
  let encoded = Bytes::from_array(input[text_start:end].to_array())
  let decoded = match encoding {
    "b" => @transfer.decode_base64(encoded, @model.Strict, 1024 * 1024).bytes
    "q" => @transfer.decode_q_word(encoded, 1024 * 1024)
    other => raise @model.InvalidEncodedWord("unsupported encoded-word encoding " + other)
  }
  {
    value: decode_word_charset(decoded, charset),
    end: end + 2,
  } |> Some
}

///|
fn decode_word_charset(input : Bytes, charset : String) -> String raise @model.MimeError {
  match @bytesutil.lower_string(charset) {
    "utf-8" | "utf8" =>
      @utf8.decode(input) catch {
        _ => raise @model.InvalidEncodedWord("encoded-word contains malformed UTF-8")
      }
    "us-ascii" | "ascii" => {
      for byte in input {
        if byte >= b'\x80' {
          raise @model.InvalidEncodedWord("US-ASCII encoded-word contains a non-ASCII byte")
        }
      }
      @utf8.decode(input) catch {
        _ => raise @model.InvalidEncodedWord("US-ASCII encoded-word is malformed")
      }
    }
    "iso-8859-1" | "latin1" | "latin-1" => @bytesutil.latin1_string(input)
    unsupported => raise @model.UnsupportedCharset(unsupported)
  }
}

///|
fn starts_word(input : Bytes, offset : Int) -> Bool {
  offset + 1 < input.length() && input[offset] == b'=' && input[offset + 1] == b'?'
}

///|
fn find_byte(input : Bytes, wanted : Byte, start : Int) -> Int? {
  for index in start..<input.length() {
    if input[index] == wanted {
      return Some(index)
    }
  }
  None
}

///|
fn is_linear_whitespace(byte : Byte) -> Bool {
  byte == b' ' || byte == b'\t' || byte == b'\r' || byte == b'\n'
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

///|
fn append_bounded(
  builder : StringBuilder,
  value : String,
  current : Int,
  limit : Int,
) -> Int raise @model.MimeError {
  let added = @utf8.encode(value).length()
  if current + added > limit {
    raise @model.DecodedOutputTooLarge(current + added, limit)
  }
  builder.write_string(value)
  current + added
}
