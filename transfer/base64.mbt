///|
/// Details retained from MIME Base64 transfer decoding.
pub(all) struct Base64Result {
  bytes : Bytes
  ignored_whitespace : Int
  unpadded : Bool
} derive(Debug, Eq)

///|
/// Decode MIME Base64 with bounded allocation and canonical tail checks.
///
/// ASCII whitespace is ignored as required for folded MIME bodies. Compatible
/// mode accepts a final unpadded group of two or three symbols and exposes that
/// fact to the caller; all other alphabet and padding damage remains fatal.
pub fn decode_base64(
  input : Bytes,
  mode : @model.ParseMode,
  max_output : Int,
) -> Base64Result raise @model.MimeError {
  if max_output <= 0 {
    raise @model.InvalidArgument("max_output must be greater than zero")
  }
  let output : Array[Byte] = []
  let quartet : Array[Int] = []
  let positions : Array[Int] = []
  let mut whitespace = 0
  let mut saw_padding = false
  for index in 0..<input.length() {
    let byte = input[index]
    if @bytesutil.is_ascii_space(byte) {
      whitespace = whitespace + 1
      continue
    }
    if saw_padding {
      raise @model.InvalidBase64(index, "non-whitespace data follows padding")
    }
    let value = if byte == b'=' {
      -1
    } else {
      match base64_value(byte) {
        Some(value) => value
        None =>
          raise @model.InvalidBase64(
            index,
            "byte 0x" +
            @bytesutil.byte_hex(byte) +
            " is not in the Base64 alphabet",
          )
      }
    }
    quartet.push(value)
    positions.push(index)
    if quartet.length() == 4 {
      let padded = decode_quartet(output, quartet, positions, max_output)
      saw_padding = padded
      quartet.clear()
      positions.clear()
    }
  }
  let mut unpadded = false
  if quartet.length() != 0 {
    if mode == @model.Strict {
      raise @model.InvalidBase64(
        positions[0],
        "final Base64 quantum is not four symbols",
      )
    }
    unpadded = true
    decode_unpadded(output, quartet, positions, max_output)
  }
  {
    bytes: Bytes::from_array(output),
    ignored_whitespace: whitespace,
    unpadded,
  }
}

///|
fn base64_value(byte : Byte) -> Int? {
  if byte >= b'A' && byte <= b'Z' {
    Some(byte.to_int() - b'A'.to_int())
  } else if byte >= b'a' && byte <= b'z' {
    Some(byte.to_int() - b'a'.to_int() + 26)
  } else if byte >= b'0' && byte <= b'9' {
    Some(byte.to_int() - b'0'.to_int() + 52)
  } else if byte == b'+' {
    Some(62)
  } else if byte == b'/' {
    Some(63)
  } else {
    None
  }
}

///|
fn decode_quartet(
  output : Array[Byte],
  quartet : Array[Int],
  positions : Array[Int],
  max_output : Int,
) -> Bool raise @model.MimeError {
  let a = quartet[0]
  let b = quartet[1]
  let c = quartet[2]
  let d = quartet[3]
  if a < 0 || b < 0 {
    let offset = if a < 0 { positions[0] } else { positions[1] }
    raise @model.InvalidBase64(
      offset, "padding is not permitted in the first two symbols",
    )
  }
  if c < 0 {
    if d >= 0 {
      raise @model.InvalidBase64(
        positions[3],
        "data symbol follows padding in one quantum",
      )
    }
    if (b & 15) != 0 {
      raise @model.InvalidBase64(
        positions[1],
        "non-zero unused bits in one-byte tail",
      )
    }
    ensure_output(output.length() + 1, max_output)
    output.push(((a << 2) | (b >> 4)).to_byte())
    return true
  }
  if d < 0 {
    if (c & 3) != 0 {
      raise @model.InvalidBase64(
        positions[2],
        "non-zero unused bits in two-byte tail",
      )
    }
    ensure_output(output.length() + 2, max_output)
    output.push(((a << 2) | (b >> 4)).to_byte())
    output.push((((b & 15) << 4) | (c >> 2)).to_byte())
    return true
  }
  ensure_output(output.length() + 3, max_output)
  output.push(((a << 2) | (b >> 4)).to_byte())
  output.push((((b & 15) << 4) | (c >> 2)).to_byte())
  output.push((((c & 3) << 6) | d).to_byte())
  false
}

///|
fn decode_unpadded(
  output : Array[Byte],
  quartet : Array[Int],
  positions : Array[Int],
  max_output : Int,
) -> Unit raise @model.MimeError {
  if quartet.length() == 1 {
    raise @model.InvalidBase64(
      positions[0],
      "one symbol cannot encode a complete byte",
    )
  }
  for index in 0..<quartet.length() {
    if quartet[index] < 0 {
      raise @model.InvalidBase64(positions[index], "incomplete padded quantum")
    }
  }
  let a = quartet[0]
  let b = quartet[1]
  if quartet.length() == 2 {
    if (b & 15) != 0 {
      raise @model.InvalidBase64(
        positions[1],
        "non-zero unused bits in unpadded tail",
      )
    }
    ensure_output(output.length() + 1, max_output)
    output.push(((a << 2) | (b >> 4)).to_byte())
    return
  }
  let c = quartet[2]
  if (c & 3) != 0 {
    raise @model.InvalidBase64(
      positions[2],
      "non-zero unused bits in unpadded tail",
    )
  }
  ensure_output(output.length() + 2, max_output)
  output.push(((a << 2) | (b >> 4)).to_byte())
  output.push((((b & 15) << 4) | (c >> 2)).to_byte())
}

///|
fn ensure_output(actual : Int, limit : Int) -> Unit raise @model.MimeError {
  if actual > limit {
    raise @model.DecodedOutputTooLarge(actual, limit)
  }
}
