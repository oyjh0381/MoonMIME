///|
fn parse_compatible(text : String) -> @model.InternetMessage raise {
  @parser.parse_message(@utf8.encode(text), mode=@model.Compatible)
}

///|
test "audit reports conflicting content type with byte evidence" {
  let message = parse_compatible(
    "Content-Type: text/plain\r\nContent-Type: application/octet-stream\r\n\r\nbody",
  )
  let report = audit_message(message)
  assert_eq(report.high, 1)
  assert_eq(report.findings[0].code, ConflictingSingletonHeader)
  assert_true(report.findings[0].evidence_range.length() > 0)
}

///|
test "audit distinguishes identical duplicate singleton" {
  let message = parse_compatible("Subject: same\r\nSubject: same\r\n\r\nbody")
  let report = audit_message(message)
  assert_eq(report.medium, 1)
  assert_eq(report.findings[0].code, DuplicateSingletonHeader)
}

///|
test "audit catches traversal attachment filename" {
  let message = parse_compatible(
    "Content-Disposition: attachment; filename=\"../drop.exe\"\r\n\r\ndata",
  )
  let report = audit_message(message)
  assert_eq(report.high, 1)
  assert_eq(report.medium, 1)
  assert_true(report.risk_score >= 35)
}

///|
test "audit catches executable suffix case insensitively" {
  let message = parse_compatible(
    "Content-Disposition: attachment; filename=INVOICE.Ps1\r\n\r\ndata",
  )
  let report = audit_message(message)
  assert_eq(report.medium, 1)
  assert_eq(report.findings[0].code, ExecutableAttachmentName)
}

///|
test "audit reports opaque encoded embedded message" {
  let message = parse_compatible(
    "Content-Type: message/rfc822\r\nContent-Transfer-Encoding: base64\r\n\r\nU3ViamVjdDogWA0KDQpY",
  )
  let report = audit_message(message)
  assert_true(
    report.findings.iter().any(fn(f) { f.code == OpaqueEmbeddedMessage }),
  )
}

///|
test "audit maps compatible bare LF recovery" {
  let message = parse_compatible("Subject: x\n\nbody")
  let report = audit_message(message)
  assert_true(report.medium >= 1)
  assert_true(
    report.findings.iter().any(fn(f) { f.code == NonCanonicalLineEnding }),
  )
}

///|
test "clean ordinary message has zero findings" {
  let message = parse_compatible(
    "From: sender@example.test\r\nSubject: report\r\nContent-Type: text/plain\r\n\r\nhello",
  )
  let report = audit_message(message)
  assert_eq(report.findings.length(), 0)
  assert_eq(report.risk_score, 0)
}

///|
test "audit renderers expose stable schema and evidence" {
  let report = audit_message(
    parse_compatible("Subject: trusted\r\nSubject: forged\r\n\r\nbody"),
  )
  let json = render_json(report)
  assert_true(json.has_prefix("{\"schema\":\"moonmime.audit.v1\""))
  assert_true(json.contains("conflicting-singleton-header"))
  assert_true(json.contains("\"start\":"))
  let text = render_summary(report)
  assert_true(text.contains("risk-score: 25/100"))
  assert_true(text.contains("bytes="))
}
