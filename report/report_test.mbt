///|
fn report_message(text : String) -> @model.InternetMessage raise {
  @parser.parse_message(@utf8.encode(text))
}

///|
test "summary includes entity table" {
  let result = render_summary(
    report_message("Content-Type: text/plain\r\n\r\nhello"),
  )
  assert_true(result.contains("MoonMIME message"))
  assert_true(result.contains("text/plain"))
  assert_true(result.contains("leaf"))
}

///|
test "json carries stable schema and stats" {
  let result = render_json(report_message("\r\nbody"))
  assert_true(result.has_prefix("{\"schema\":\"moonmime.inspect.v1\""))
  assert_true(result.contains("\"entities\":1"))
  assert_true(result.contains("\"raw_bytes\":6"))
}

///|
test "json renders paths and attachment metadata" {
  let result = render_json(
    report_message(
      "Content-Disposition: attachment; filename=a.txt\r\nContent-Type: text/plain\r\n\r\ndata",
    ),
  )
  assert_true(result.contains("\"path\":[]"))
  assert_true(result.contains("\"filename\":\"a.txt\""))
  assert_true(result.contains("\"explicit\":true"))
}

///|
test "json escapes quote slash and control bytes" {
  let message = report_message(
    "Content-Disposition: attachment; filename=\"a\\\"b\\\\c\"\r\n\r\ndata",
  )
  let result = render_json(message)
  assert_true(result.contains("a\\\"b\\\\c"))
}

///|
test "json preserves Unicode filenames" {
  let message = report_message(
    "Content-Disposition: attachment; filename*=UTF-8''%E6%B5%8B%E8%AF%95.txt\r\n\r\ndata",
  )
  assert_true(render_json(message).contains("测试.txt"))
}

///|
test "summary shows nested dot paths" {
  let message = report_message(
    "Content-Type: multipart/mixed; boundary=o\r\n\r\n--o\r\nContent-Type: message/rfc822\r\n\r\n\r\ninner\r\n--o--\r\n",
  )
  let result = render_summary(message)
  assert_true(result.contains("0.0"))
}
