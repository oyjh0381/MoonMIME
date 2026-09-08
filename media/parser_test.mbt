///|
test "media type parser normalizes essence and preserves parameters" {
  let media = parse_media_type(
    " Text/HTML ; charset=\"utf-8\"; format=flowed ",
    @model.Strict,
    8,
  )
  assert_eq(media.essence(), "text/html")
  assert_eq(media.parameters.length(), 2)
  assert_eq(media.parameter("charset"), Some("utf-8"))
  assert_eq(media.parameter("format"), Some("flowed"))
}

///|
test "quoted parameter handles quoted-pair" {
  let media = parse_media_type(
    "multipart/mixed; boundary=\"a\\\"b\\\\c\"",
    @model.Strict,
    8,
  )
  assert_eq(media.parameter("boundary"), Some("a\"b\\c"))
}

///|
test "content disposition normalizes kind" {
  let disposition = parse_content_disposition(
    " Attachment; filename=report.pdf ",
    @model.Strict,
    8,
  )
  assert_eq(disposition.kind, "attachment")
  assert_eq(disposition.parameter("filename"), Some("report.pdf"))
}

///|
test "invalid disposition uses disposition error category" {
  let mut failed = false
  ignore(parse_content_disposition("; filename=a", @model.Strict, 8)) catch {
    @model.InvalidDisposition("expected disposition type") => failed = true
    _ => ()
  }
  assert_true(failed)
}

///|
test "invalid disposition parameter uses disposition error category" {
  let mut failed = false
  ignore(parse_content_disposition("attachment; =a", @model.Strict, 8)) catch {
    @model.InvalidDisposition("expected parameter name") => failed = true
    _ => ()
  }
  assert_true(failed)
}

///|
test "extended parameter names expose section metadata" {
  let disposition = parse_content_disposition(
    "attachment; filename*0*=utf-8''long%20; filename*1=name.txt",
    @model.Strict,
    8,
  )
  assert_eq(disposition.parameters[0].lower_name, "filename")
  assert_eq(disposition.parameters[0].section, Some(0))
  assert_true(disposition.parameters[0].encoded)
  assert_eq(disposition.parameters[1].section, Some(1))
  assert_false(disposition.parameters[1].encoded)
}

///|
test "transfer encoding recognizes standard tokens" {
  assert_eq(parse_transfer_encoding(" BASE64 \t"), @model.Base64)
  assert_eq(parse_transfer_encoding("quoted-printable"), @model.QuotedPrintable)
  assert_eq(parse_transfer_encoding("X-CUSTOM"), @model.Extension("x-custom"))
}

///|
test "strict media parser rejects trailing semicolon" {
  assert_media_failure("text/plain;", "MOONMIME_MEDIA_TYPE")
}

///|
test "compatible media parser accepts trailing semicolon" {
  let media = parse_media_type("text/plain;", @model.Compatible, 8)
  assert_eq(media.essence(), "text/plain")
  assert_eq(media.parameters.length(), 0)
}

///|
test "media parser rejects missing subtype" {
  assert_media_failure("text", "MOONMIME_MEDIA_TYPE")
}

///|
test "media parser rejects unterminated quoted parameter" {
  assert_media_failure("text/plain; charset=\"utf-8", "MOONMIME_MEDIA_TYPE")
}

///|
test "parameter parser enforces configured count" {
  let mut code : String? = None
  ignore(parse_media_type("text/plain; a=1; b=2", @model.Strict, 1)) catch {
    error => code = Some(error.code())
  }
  assert_eq(code, Some("MOONMIME_ARGUMENT"))
}

///|
fn assert_media_failure(source : String, expected : String) -> Unit raise {
  let mut code : String? = None
  ignore(parse_media_type(source, @model.Strict, 16)) catch {
    error => code = Some(error.code())
  }
  assert_eq(code, Some(expected))
}
