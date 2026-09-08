///|
test "header parser preserves order and duplicate fields" {
  let input = @utf8.encode(
    "Received: first\r\nSubject: hello\r\nReceived: second\r\n\r\nbody",
  )
  let result = parse_header_block(
    input,
    0,
    input.length(),
    @model.Strict,
    @model.ResourceLimits::secure_defaults(),
  )
  assert_eq(result.block.fields.length(), 3)
  assert_eq(result.block.all("received").map(field => field.value), [
    "first", "second",
  ])
  assert_eq(result.block.first("subject").unwrap().value, "hello")
  assert_eq(input[result.block.body_start], b'b')
}

///|
test "header parser unfolds continuation lines with one space" {
  let input = @utf8.encode("Subject: first\r\n\t second  \r\n third\r\n\r\n")
  let result = parse_header_block(
    input,
    0,
    input.length(),
    @model.Strict,
    @model.ResourceLimits::secure_defaults(),
  )
  let subject = result.block.first("subject").unwrap()
  assert_eq(subject.value, "first second third")
  assert_eq(subject.line_count, 3)
}

///|
test "compatible mode accepts LF and reports every line ending" {
  let input = @utf8.encode("From: a@example.test\nSubject: hi\n\nbody")
  let result = parse_header_block(
    input,
    0,
    input.length(),
    @model.Compatible,
    @model.ResourceLimits::secure_defaults(),
  )
  assert_eq(result.block.fields.length(), 2)
  assert_eq(result.diagnostics.length(), 3)
  assert_true(result.diagnostics.all(item => item.code == @model.BareLineFeed))
}

///|
test "strict mode rejects LF line endings" {
  assert_header_failure(
    "Subject: no\n\n",
    @model.Strict,
    "MOONMIME_MALFORMED_HEADER",
  )
}

///|
test "compatible mode ignores a line without colon with diagnostic" {
  let input = @utf8.encode("Broken line\r\nSubject: kept\r\n\r\n")
  let result = parse_header_block(
    input,
    0,
    input.length(),
    @model.Compatible,
    @model.ResourceLimits::secure_defaults(),
  )
  assert_eq(result.block.fields.length(), 1)
  assert_eq(result.block.fields[0].name, "Subject")
  assert_true(
    result.diagnostics.any(item => item.code == @model.HeaderWithoutColon),
  )
}

///|
test "strict mode rejects whitespace before colon" {
  assert_header_failure(
    "Subject : bad\r\n\r\n",
    @model.Strict,
    "MOONMIME_MALFORMED_HEADER",
  )
}

///|
test "compatible mode trims whitespace before colon" {
  let input = @utf8.encode("Subject : accepted\r\n\r\n")
  let result = parse_header_block(
    input,
    0,
    input.length(),
    @model.Compatible,
    @model.ResourceLimits::secure_defaults(),
  )
  assert_eq(result.block.fields[0].lower_name, "subject")
  assert_eq(result.block.fields[0].value, "accepted")
  assert_eq(result.diagnostics[0].code, @model.HeaderWhitespaceBeforeColon)
}

///|
test "header parser enforces physical line length" {
  let defaults = @model.ResourceLimits::secure_defaults()
  let limits : @model.ResourceLimits = { ..defaults, max_header_line_bytes: 8, }
  let input = @utf8.encode("Subject: too-long\r\n\r\n")
  let mut code : String? = None
  ignore(parse_header_block(input, 0, input.length(), @model.Strict, limits)) catch {
    error => code = Some(error.code())
  }
  assert_eq(code, Some("MOONMIME_HEADER_LINE_LIMIT"))
}

///|
test "header parser enforces field count" {
  let defaults = @model.ResourceLimits::secure_defaults()
  let limits : @model.ResourceLimits = { ..defaults, max_header_count: 1, }
  let input = @utf8.encode("A: 1\r\nB: 2\r\n\r\n")
  let mut code : String? = None
  ignore(parse_header_block(input, 0, input.length(), @model.Strict, limits)) catch {
    error => code = Some(error.code())
  }
  assert_eq(code, Some("MOONMIME_HEADER_COUNT_LIMIT"))
}

///|
test "header parser requires empty-line terminator" {
  assert_header_failure(
    "Subject: truncated",
    @model.Strict,
    "MOONMIME_HEADER_TERMINATOR",
  )
}

///|
fn assert_header_failure(
  source : String,
  mode : @model.ParseMode,
  expected : String,
) -> Unit raise {
  let input = @utf8.encode(source)
  let mut code : String? = None
  ignore(
    parse_header_block(
      input,
      0,
      input.length(),
      mode,
      @model.ResourceLimits::secure_defaults(),
    ),
  ) catch {
    error => code = Some(error.code())
  }
  assert_eq(code, Some(expected))
}
