///|
/// Bounded result of applying one Content-Transfer-Encoding.
pub(all) struct TransferDecodeResult {
  bytes : Bytes
  encoding : @model.TransferEncoding
  transformed : Bool
  compatibility_recovery : Bool
} derive(Debug, Eq)

///|
/// Decode a leaf body according to its normalized transfer encoding.
///
/// Identity encodings still copy through a size check. Unknown extensions are
/// rejected in strict mode and preserved byte-for-byte in compatible mode.
pub fn decode_transfer(
  input : Bytes,
  encoding : @model.TransferEncoding,
  mode : @model.ParseMode,
  max_output : Int,
) -> TransferDecodeResult raise @model.MimeError {
  if max_output <= 0 {
    raise @model.InvalidArgument("max_output must be greater than zero")
  }
  match encoding {
    @model.Base64 => {
      let result = decode_base64(input, mode, max_output)
      {
        bytes: result.bytes,
        encoding,
        transformed: true,
        compatibility_recovery: result.unpadded,
      }
    }
    @model.QuotedPrintable => {
      let result = decode_quoted_printable(input, mode, max_output)
      {
        bytes: result.bytes,
        encoding,
        transformed: true,
        compatibility_recovery: result.bare_lf_soft_breaks > 0,
      }
    }
    @model.SevenBit => {
      validate_identity(input, max_output)
      validate_seven_bit(input)
      { bytes: input, encoding, transformed: false, compatibility_recovery: false }
    }
    @model.EightBit | @model.Binary => {
      validate_identity(input, max_output)
      { bytes: input, encoding, transformed: false, compatibility_recovery: false }
    }
    @model.Extension(value) => {
      if mode == @model.Strict {
        raise @model.UnsupportedTransferEncoding(value)
      }
      validate_identity(input, max_output)
      { bytes: input, encoding, transformed: false, compatibility_recovery: true }
    }
  }
}

///|
/// Slice and decode one entity body from its owning Internet Message.
pub fn decode_entity_body(
  message : @model.InternetMessage,
  entity : @model.MimeEntity,
  mode : @model.ParseMode,
  max_output? : Int = -1,
) -> TransferDecodeResult raise @model.MimeError {
  entity.body_range.validate(message.raw.length())
  let limit = if max_output < 0 {
    @model.ResourceLimits::secure_defaults().max_decoded_leaf_bytes
  } else {
    max_output
  }
  decode_transfer(
    Bytes::from_array(message.raw[entity.body_range.start:entity.body_range.end].to_array()),
    entity.transfer_encoding,
    mode,
    limit,
  )
}

///|
fn validate_identity(input : Bytes, max_output : Int) -> Unit raise @model.MimeError {
  if input.length() > max_output {
    raise @model.DecodedOutputTooLarge(input.length(), max_output)
  }
}

///|
fn validate_seven_bit(input : Bytes) -> Unit raise @model.MimeError {
  for index in 0..<input.length() {
    if input[index] >= b'\x80' {
      raise @model.UnsupportedTransferEncoding(
        "7bit body contains non-ASCII octet at offset \{index}",
      )
    }
  }
}
