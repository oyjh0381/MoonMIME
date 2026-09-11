///|
fn assert_has_code(text : String, code : AuditCode) -> Unit raise {
  let report = audit_message(parse_compatible(text))
  assert_true(report.findings.iter().any(fn(finding) { finding.code == code }))
}

///|
test "security matrix: 10 conflicting Content-Type variants" {
  let types = [
    "application/octet-stream", "text/html", "image/png", "application/pdf", "message/rfc822",
    "application/zip", "audio/wav", "video/mp4", "application/json", "text/calendar",
  ]
  for media_type in types {
    assert_has_code(
      "Content-Type: text/plain\r\nContent-Type: " + media_type + "\r\n\r\nbody",
      ConflictingSingletonHeader,
    )
  }
}

///|
test "security matrix: 10 conflicting identity and MIME fields" {
  let names = [
    "subject", "from", "sender", "reply-to", "message-id", "mime-version", "content-disposition",
    "content-transfer-encoding", "content-type", "subject",
  ]
  for name in names {
    assert_has_code(
      name + ": first\r\n" + name + ": second\r\n\r\nbody",
      ConflictingSingletonHeader,
    )
  }
}

///|
test "security matrix: 10 path-bearing attachment names" {
  let names = [
    "../a.txt", "../../a.txt", "dir/a.txt", "deep/dir/a.txt", "C:a.txt", "scheme:a.txt",
    "/tmp/a.txt", "./a.txt", ":hidden.txt", "safe/../a.txt",
  ]
  for name in names {
    assert_has_code(
      "Content-Disposition: attachment; filename=\"" + name + "\"\r\n\r\ndata",
      UnsafeAttachmentFilename,
    )
  }
}

///|
test "security matrix: 10 executable attachment suffixes" {
  let names = [
    "a.exe", "a.com", "a.bat", "a.cmd", "a.ps1", "a.js", "a.vbs", "a.scr", "a.msi",
    "INVOICE.EXE",
  ]
  for name in names {
    assert_has_code(
      "Content-Disposition: attachment; filename=\"" + name + "\"\r\n\r\ndata",
      ExecutableAttachmentName,
    )
  }
}

///|
test "security matrix: 10 non-canonical line-ending variants" {
  for index in 0..<10 {
    assert_has_code(
      "From: sender" + index.to_string() + "@example.test\nSubject: x\n\nbody",
      NonCanonicalLineEnding,
    )
  }
}

///|
test "security matrix: 10 opaque embedded-message variants" {
  let encodings = [
    "base64", "quoted-printable", "x-one", "x-two", "x-three", "x-four", "x-five",
    "x-six", "x-seven", "x-eight",
  ]
  for encoding in encodings {
    assert_has_code(
      "Content-Type: message/rfc822\r\nContent-Transfer-Encoding: " +
      encoding +
      "\r\n\r\nU3ViamVjdDogWA==",
      OpaqueEmbeddedMessage,
    )
  }
}

///|
test "security matrix: 20 benign controls remain finding-free" {
  for index in 0..<20 {
    let message = parse_compatible(
      "From: sender" +
      index.to_string() +
      "@example.test\r\nSubject: report " +
      index.to_string() +
      "\r\nContent-Type: text/plain\r\n\r\nhello",
    )
    assert_eq(audit_message(message).findings.length(), 0)
  }
}
