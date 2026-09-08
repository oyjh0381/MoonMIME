///|
fn parse_text(
  text : String,
  mode? : @model.ParseMode = @model.Strict,
) -> @model.InternetMessage raise {
  parse_message(@utf8.encode(text), mode~)
}

///|
test "simple message becomes one leaf entity" {
  let message = parse_text("From: a@example.test\r\nSubject: hi\r\n\r\nhello")
  assert_eq(message.root.kind, @model.Leaf)
  assert_eq(message.root.media_type.essence(), "text/plain")
  assert_eq(message.stats.entities, 1)
  assert_eq(message.stats.leaf_entities, 1)
}

///|
test "multipart message creates ordered child paths" {
  let message = parse_text(
    "Content-Type: multipart/mixed; boundary=outer\r\n\r\npreamble\r\n--outer\r\nContent-Type: text/plain\r\n\r\none\r\n--outer\r\nContent-Type: application/octet-stream\r\nContent-Disposition: attachment; filename=a.bin\r\n\r\ntwo\r\n--outer--\r\nepilogue",
  )
  assert_eq(message.root.kind, @model.Multipart)
  assert_eq(message.root.children.length(), 2)
  assert_eq(message.root.children[0].path, [0])
  assert_eq(message.root.children[1].path, [1])
  assert_eq(message.root.children[1].filename(), Some("a.bin"))
  assert_eq(message.stats.entities, 3)
}

///|
test "multipart preserves preamble and epilogue ranges" {
  let message = parse_text(
    "Content-Type: multipart/mixed; boundary=x\r\n\r\nPRE\r\n--x\r\n\r\nbody\r\n--x--\r\nEPI",
  )
  let pre = message.root.preamble_range.unwrap()
  let epi = message.root.epilogue_range.unwrap()
  assert_eq(@utf8.decode(message.raw[pre.start:pre.end]), "PRE\r\n")
  assert_eq(@utf8.decode(message.raw[epi.start:epi.end]), "EPI")
}

///|
test "nested multipart tracks depth and paths" {
  let message = parse_text(
    "Content-Type: multipart/mixed; boundary=o\r\n\r\n--o\r\nContent-Type: multipart/alternative; boundary=i\r\n\r\n--i\r\nContent-Type: text/plain\r\n\r\nplain\r\n--i--\r\n\r\n--o--\r\n",
  )
  assert_eq(message.root.children[0].children[0].path, [0, 0])
  assert_eq(message.stats.maximum_depth, 2)
  assert_eq(message.stats.multipart_entities, 2)
}

///|
test "message rfc822 creates embedded child" {
  let message = parse_text(
    "Content-Type: message/rfc822\r\n\r\nFrom: inner@example.test\r\n\r\ninside",
  )
  assert_eq(message.root.kind, @model.EmbeddedMessage)
  assert_eq(message.root.children.length(), 1)
  assert_eq(message.root.children[0].path, [0])
  assert_eq(message.stats.embedded_messages, 1)
}

///|
test "strict multipart requires closing boundary" {
  let mut failed = false
  ignore(
    parse_text(
      "Content-Type: multipart/mixed; boundary=x\r\n\r\n--x\r\n\r\nbody",
    ),
  ) catch {
    @model.MissingClosingBoundary("x") => failed = true
    _ => ()
  }
  assert_true(failed)
}

///|
test "compatible multipart accepts missing closing boundary" {
  let message = parse_text(
    "Content-Type: multipart/mixed; boundary=x\r\n\r\n--x\r\n\r\nbody",
    mode=@model.Compatible,
  )
  assert_eq(message.root.children.length(), 1)
  assert_eq(message.diagnostics[0].code, @model.MissingClosingBoundaryAccepted)
}

///|
test "recursion limit is enforced before deep parsing" {
  let text = "Content-Type: message/rfc822\r\n\r\nContent-Type: message/rfc822\r\n\r\n\r\n"
  let limits = { ..@model.ResourceLimits::secure_defaults(), max_depth: 1, }
  let mut failed = false
  ignore(parse_message(@utf8.encode(text), limits~)) catch {
    @model.RecursionLimitExceeded(2, 1) => failed = true
    _ => ()
  }
  assert_true(failed)
}

///|
test "entity count limit is enforced" {
  let text = "Content-Type: multipart/mixed; boundary=x\r\n\r\n--x\r\n\r\na\r\n--x\r\n\r\nb\r\n--x--\r\n"
  let limits = { ..@model.ResourceLimits::secure_defaults(), max_entities: 2, }
  let mut failed = false
  ignore(parse_message(@utf8.encode(text), limits~)) catch {
    @model.EntityCountExceeded(3, 2) => failed = true
    _ => ()
  }
  assert_true(failed)
}

///|
test "input size limit is checked before parsing" {
  let limits = {
    ..@model.ResourceLimits::secure_defaults(),
    max_input_bytes: 4,
    max_header_bytes: 4,
    max_leaf_body_bytes: 4,
  }
  let mut failed = false
  ignore(parse_message(@utf8.encode("A: b\r\n\r\n"), limits~)) catch {
    @model.InputTooLarge(_, 4) => failed = true
    _ => ()
  }
  assert_true(failed)
}

///|
test "boundary prefix in body does not create a child" {
  let message = parse_text(
    "Content-Type: multipart/mixed; boundary=x\r\n\r\n--x\r\n\r\na\r\n--x-extra\r\nb\r\n--x--\r\n",
  )
  assert_eq(message.root.children.length(), 1)
}

///|
test "leaf body size is bounded" {
  let limits = {
    ..@model.ResourceLimits::secure_defaults(),
    max_leaf_body_bytes: 3,
  }
  let mut failed = false
  ignore(parse_message(@utf8.encode("\r\nabcd"), limits~)) catch {
    @model.LeafBodyTooLarge(4, 3) => failed = true
    _ => ()
  }
  assert_true(failed)
}
