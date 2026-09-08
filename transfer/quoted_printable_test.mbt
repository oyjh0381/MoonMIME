///|
test "Quoted-Printable decodes escaped octets" {
  let result = decode_quoted_printable(
    b"Hello=2C=20MoonBit=21",
    @model.Strict,
    128,
  )
  assert_eq(result.bytes, b"Hello, MoonBit!")
  assert_eq(result.escaped_octets, 3)
}

///|
test "Quoted-Printable removes CRLF soft breaks" {
  let result = decode_quoted_printable(b"one=\r\ntwo", @model.Strict, 128)
  assert_eq(result.bytes, b"onetwo")
  assert_eq(result.soft_line_breaks, 1)
  assert_eq(result.bare_lf_soft_breaks, 0)
}

///|
test "compatible Quoted-Printable reports bare LF soft breaks" {
  let result = decode_quoted_printable(b"one=\ntwo", @model.Compatible, 128)
  assert_eq(result.bytes, b"onetwo")
  assert_eq(result.bare_lf_soft_breaks, 1)
}

///|
test "strict Quoted-Printable rejects bare LF soft breaks" {
  assert_qp_failure(b"one=\ntwo", @model.Strict, 128, "MOONMIME_QUOTED_PRINTABLE")
}

///|
test "Quoted-Printable rejects malformed hexadecimal escape" {
  assert_qp_failure(b"bad=GG", @model.Strict, 128, "MOONMIME_QUOTED_PRINTABLE")
}

///|
test "Quoted-Printable rejects dangling equals" {
  assert_qp_failure(b"bad=", @model.Strict, 128, "MOONMIME_QUOTED_PRINTABLE")
}

///|
test "Quoted-Printable enforces decoded output limit" {
  assert_qp_failure(b"abcdef", @model.Strict, 5, "MOONMIME_DECODED_LIMIT")
}

///|
test "Q encoded-word maps underscore and hex escapes" {
  assert_eq(decode_q_word(b"Hello_World=21", 64), b"Hello World!")
}

///|
test "Q encoded-word rejects raw question mark" {
  let mut code : String? = None
  ignore(decode_q_word(b"bad?word", 64)) catch {
    error => code = Some(error.code())
  }
  assert_eq(code, Some("MOONMIME_QUOTED_PRINTABLE"))
}

///|
fn assert_qp_failure(
  input : Bytes,
  mode : @model.ParseMode,
  limit : Int,
  expected : String,
) -> Unit raise {
  let mut code : String? = None
  ignore(decode_quoted_printable(input, mode, limit)) catch {
    error => code = Some(error.code())
  }
  assert_eq(code, Some(expected))
}
