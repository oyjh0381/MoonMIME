///|
test "transfer facade decodes Base64" {
  let result = decode_transfer(
    @utf8.encode("aGVsbG8="),
    @model.Base64,
    @model.Strict,
    16,
  )
  assert_eq(@utf8.decode(result.bytes), "hello")
  assert_true(result.transformed)
  assert_false(result.compatibility_recovery)
}

///|
test "transfer facade decodes Quoted-Printable" {
  let result = decode_transfer(
    @utf8.encode("caf=C3=A9"),
    @model.QuotedPrintable,
    @model.Strict,
    16,
  )
  assert_eq(@utf8.decode(result.bytes), "café")
  assert_true(result.transformed)
}

///|
test "identity transfer remains byte exact" {
  let raw = Bytes::from_array([0, 1, 255])
  let result = decode_transfer(raw, @model.Binary, @model.Strict, 3)
  assert_eq(result.bytes, raw)
  assert_false(result.transformed)
}

///|
test "seven bit transfer rejects high octets" {
  let mut failed = false
  ignore(
    decode_transfer(Bytes::from_array([128]), @model.SevenBit, @model.Strict, 3),
  ) catch {
    @model.UnsupportedTransferEncoding(_) => failed = true
    _ => ()
  }
  assert_true(failed)
}

///|
test "strict facade rejects extension encoding" {
  let mut failed = false
  ignore(
    decode_transfer(
      @utf8.encode("raw"),
      @model.Extension("x-z"),
      @model.Strict,
      8,
    ),
  ) catch {
    @model.UnsupportedTransferEncoding("x-z") => failed = true
    _ => ()
  }
  assert_true(failed)
}

///|
test "compatible facade preserves extension encoding" {
  let result = decode_transfer(
    @utf8.encode("raw"),
    @model.Extension("x-z"),
    @model.Compatible,
    8,
  )
  assert_eq(@utf8.decode(result.bytes), "raw")
  assert_true(result.compatibility_recovery)
}

///|
test "identity transfer enforces output bound" {
  let mut failed = false
  ignore(
    decode_transfer(@utf8.encode("four"), @model.EightBit, @model.Strict, 3),
  ) catch {
    @model.DecodedOutputTooLarge(4, 3) => failed = true
    _ => ()
  }
  assert_true(failed)
}

///|
test "compatible unpadded Base64 marks recovery" {
  let result = decode_transfer(
    @utf8.encode("aGk"),
    @model.Base64,
    @model.Compatible,
    8,
  )
  assert_eq(@utf8.decode(result.bytes), "hi")
  assert_true(result.compatibility_recovery)
}
