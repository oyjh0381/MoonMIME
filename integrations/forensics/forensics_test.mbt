///|
test "forensic manifest binds source and attachment bytes" {
  let raw =
    #|Message-ID: <evidence-42@example.test>
    #|Subject: Quarterly evidence
    #|Content-Type: multipart/mixed; boundary="case"
    #|
    #|--case
    #|Content-Type: text/plain
    #|
    #|cover
    #|--case
    #|Content-Type: application/octet-stream
    #|Content-Disposition: attachment; filename="record.bin"
    #|
    #|EVIDENCE-BYTES
    #|--case--
  let manifest = build_manifest(
    @utf8.encode(raw),
    "CASE-2026-0042",
    "mailbox/42.eml",
  )
  assert_eq(manifest.case_id, "CASE-2026-0042")
  assert_eq(manifest.message_id, Some("<evidence-42@example.test>"))
  assert_eq(manifest.attachments.length(), 1)
  assert_eq(manifest.attachments[0].filename, Some("record.bin"))
  assert_eq(
    manifest.attachments[0].encoded_sha256,
    @sha256.digest_hex(b"EVIDENCE-BYTES"),
  )
  let json = render_json(manifest)
  assert_true(json.contains("\"schema\":\"moonmime.forensics.v1\""))
  assert_true(json.contains("\"body_start\":"))
}

///|
test "forensic manifest rejects empty case identifiers" {
  try build_manifest(b"Subject: x\r\n\r\nbody", "  ", "x.eml") catch {
    @model.InvalidArgument(message) =>
      assert_eq(message, "case_id must not be empty")
    _ => fail("expected InvalidArgument")
  } noraise {
    _ => fail("expected empty case identifier to raise")
  }
}

///|
test "forensic JSON preserves Unicode identifiers" {
  let manifest = build_manifest(
    b"Subject: x\r\n\r\nbody", "案件-42", "邮箱/证据.eml",
  )
  let json = render_json(manifest)
  assert_true(json.contains("案件-42"))
  assert_true(json.contains("邮箱/证据.eml"))
}
