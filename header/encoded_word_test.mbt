///|
test "encoded-word decodes UTF-8 Base64" {
  let result = decode_encoded_words("=?UTF-8?B?5L2g5aW9?=", @model.Strict, 1024)
  assert_eq(result.value, "你好")
  assert_eq(result.decoded_words, 1)
}

///|
test "encoded-word decodes Q underscore and escape" {
  let result = decode_encoded_words("=?ISO-8859-1?Q?Andr=E9_Caf=E9?=", @model.Strict, 1024)
  assert_eq(result.value, "André Café")
}

///|
test "adjacent encoded-word whitespace is suppressed" {
  let result = decode_encoded_words(
    "=?UTF-8?Q?hello?= \r\n\t=?UTF-8?Q?_world?=",
    @model.Strict,
    1024,
  )
  assert_eq(result.value, "hello world")
  assert_eq(result.decoded_words, 2)
}

///|
test "ordinary whitespace after a word remains" {
  let result = decode_encoded_words("=?US-ASCII?Q?hello?= there", @model.Strict, 1024)
  assert_eq(result.value, "hello there")
}

///|
test "ordinary UTF-8 text remains unchanged" {
  let result = decode_encoded_words("主题：你好", @model.Strict, 1024)
  assert_eq(result.value, "主题：你好")
  assert_eq(result.decoded_words, 0)
}

///|
test "compatible mode preserves malformed candidate" {
  let result = decode_encoded_words("before =?UTF-8?X?bad?= after", @model.Compatible, 1024)
  assert_eq(result.value, "before =?UTF-8?X?bad?= after")
  assert_eq(result.preserved_invalid_words, 1)
}

///|
test "strict mode rejects malformed candidate" {
  let mut failed = false
  try {
    ignore(decode_encoded_words("=?UTF-8?X?bad?=", @model.Strict, 1024))
  } catch {
    @model.InvalidEncodedWord(_) => failed = true
    _ => ()
  }
  assert_true(failed)
}

///|
test "unsupported charset is structured" {
  let mut failed = false
  try {
    ignore(decode_encoded_words("=?KOI8-R?Q?hello?=", @model.Strict, 1024))
  } catch {
    @model.UnsupportedCharset("koi8-r") => failed = true
    _ => ()
  }
  assert_true(failed)
}

///|
test "output limit applies after charset decoding" {
  let mut failed = false
  try {
    ignore(decode_encoded_words("=?US-ASCII?Q?abcd?=", @model.Strict, 3))
  } catch {
    @model.DecodedOutputTooLarge(4, 3) => failed = true
    _ => ()
  }
  assert_true(failed)
}

///|
test "invalid Base64 tail is rejected" {
  let mut failed = false
  try {
    ignore(decode_encoded_words("=?UTF-8?B?A===?=", @model.Strict, 1024))
  } catch {
    @model.InvalidBase64(_, _) => failed = true
    _ => ()
  }
  assert_true(failed)
}
