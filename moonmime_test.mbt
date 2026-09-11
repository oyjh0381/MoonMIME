///|
test "root parse API handles a plain message" {
  let message = parse(@utf8.encode("Subject: hello\r\n\r\nbody"))
  assert_eq(message.root.media_type.essence(), "text/plain")
  assert_eq(message.stats.entities, 1)
}

///|
test "root inspect json API exposes stable schema" {
  let result = inspect_json(@utf8.encode("\r\nbody"))
  assert_true(result.contains("moonmime.inspect.v1"))
}

///|
test "root inspect text API exposes media type" {
  let result = inspect_text(
    @utf8.encode("Content-Type: application/json\r\n\r\n{}"),
  )
  assert_true(result.contains("application/json"))
}

///|
test "root decode body selects a leaf by path" {
  let raw = @utf8.encode(
    "Content-Type: multipart/mixed; boundary=x\r\n\r\n--x\r\nContent-Transfer-Encoding: base64\r\n\r\naGk=\r\n--x--\r\n",
  )
  let message = parse(raw)
  assert_eq(@utf8.decode(decode_body(message, [0])), "hi")
}

///|
test "root decode body rejects missing path" {
  let message = parse(@utf8.encode("\r\nbody"))
  let mut failed = false
  ignore(decode_body(message, [9])) catch {
    @model.InvalidArgument("entity path does not exist") => failed = true
    _ => ()
  }
  assert_true(failed)
}

///|
test "root decode body rejects multipart container" {
  let raw = @utf8.encode(
    "Content-Type: multipart/mixed; boundary=x\r\n\r\n--x\r\n\r\na\r\n--x--\r\n",
  )
  let message = parse(raw)
  let mut failed = false
  ignore(decode_body(message, [])) catch {
    @model.InvalidArgument("only leaf entity bodies can be decoded") =>
      failed = true
    _ => ()
  }
  assert_true(failed)
}

///|
test "root parse with accepts compatible LF input" {
  let message = parse_with(
    @utf8.encode("Subject: hello\n\nbody"),
    @model.Compatible,
    secure_limits(),
  )
  assert_true(message.diagnostics.length() > 0)
}

///|
test "edge limits remain valid" {
  edge_limits().validate()
  assert_true(edge_limits().max_input_bytes < secure_limits().max_input_bytes)
}
///|
test "root audit API exposes stable security report" {
  let result = audit_json(
    @utf8.encode("Subject: one\r\nSubject: two\r\n\r\nbody"),
  )
  assert_true(result.contains("moonmime.audit.v1"))
  assert_true(result.contains("conflicting-singleton-header"))
}
