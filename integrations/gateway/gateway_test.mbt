///|
test "gateway allows a normal message" {
  let result = @gateway.evaluate(
    b"From: sender@example.test\r\nSubject: normal\r\n\r\nhello", "queue/normal.eml",
  )
  assert_eq(result.action, Allow)
  inspect(result.entity_count, content="1")
  assert_true(result.triggered_codes.is_empty())
  assert_true(@gateway.render_json(result).contains("\"action\":\"allow\""))
}

///|
test "gateway quarantines an ambiguous message with evidence" {
  let result = @gateway.evaluate(
    b"From: trusted@example.test\r\nFrom: attacker@example.test\r\n\r\nhello", "queue/ambiguous.eml",
  )
  assert_eq(result.action, Quarantine)
  inspect(result.audit.high, content="1")
  assert_eq(result.triggered_codes.length(), 1)
  assert_eq(result.triggered_codes[0], "conflicting-singleton-header")
}

///|
test "gateway JSON preserves Unicode source identifiers" {
  let result = @gateway.evaluate(
    b"Subject: ok\r\n\r\nhello", "收件箱/邮件.eml",
  )
  assert_true(@gateway.render_json(result).contains("收件箱/邮件.eml"))
}
