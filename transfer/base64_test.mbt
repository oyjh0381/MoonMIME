///|
test "Base64 decodes the RFC 4648 short vectors" {
  let vectors = [
    ("", ""),
    ("Zg==", "f"),
    ("Zm8=", "fo"),
    ("Zm9v", "foo"),
    ("Zm9vYg==", "foob"),
    ("Zm9vYmE=", "fooba"),
    ("Zm9vYmFy", "foobar"),
  ]
  for item in vectors {
    let (encoded, expected) = item
    let result = decode_base64(@utf8.encode(encoded), @model.Strict, 1024)
    assert_eq(result.bytes, @utf8.encode(expected))
  }
}

///|
test "MIME whitespace is ignored and reported" {
  let result = decode_base64(@utf8.encode(" Zm9v\r\nYmFy\t"), @model.Strict, 64)
  assert_eq(result.bytes, b"foobar")
  assert_eq(result.ignored_whitespace, 4)
  assert_false(result.unpadded)
}

///|
test "compatible mode accepts canonical unpadded tails" {
  let one = decode_base64(b"Zg", @model.Compatible, 8)
  let two = decode_base64(b"Zm8", @model.Compatible, 8)
  assert_eq(one.bytes, b"f")
  assert_eq(two.bytes, b"fo")
  assert_true(one.unpadded)
}

///|
test "strict mode rejects an unpadded tail" {
  assert_base64_failure(b"Zg", @model.Strict, 8, "MOONMIME_BASE64")
}

///|
test "Base64 rejects alphabet damage" {
  assert_base64_failure(b"Zm$v", @model.Strict, 8, "MOONMIME_BASE64")
}

///|
test "Base64 rejects data after padding" {
  assert_base64_failure(b"Zg==QQ==", @model.Strict, 16, "MOONMIME_BASE64")
}

///|
test "Base64 rejects misplaced padding" {
  assert_base64_failure(b"=m9v", @model.Strict, 16, "MOONMIME_BASE64")
}

///|
test "Base64 rejects non-canonical unused bits" {
  assert_base64_failure(b"Zh==", @model.Strict, 16, "MOONMIME_BASE64")
  assert_base64_failure(b"Zm9=", @model.Strict, 16, "MOONMIME_BASE64")
}

///|
test "Base64 enforces output limit before growth" {
  assert_base64_failure(b"Zm9vYmFy", @model.Strict, 5, "MOONMIME_DECODED_LIMIT")
}

///|
fn assert_base64_failure(
  input : Bytes,
  mode : @model.ParseMode,
  limit : Int,
  code : String,
) -> Unit raise {
  let mut observed : String? = None
  ignore(decode_base64(input, mode, limit)) catch {
    error => observed = Some(error.code())
  }
  assert_eq(observed, Some(code))
}
