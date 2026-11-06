///|
test "manifest verification refuses altered message bytes and accepts exact evidence" {
  let raw = b"Subject: evidence\r\n\r\nhello"
  let manifest = @forensics.build_manifest(raw, "case", "message")
  assert_true(@forensics.verify_manifest(raw, manifest).valid)
  let mismatch = @forensics.verify_manifest(
    b"Subject: evidence\r\n\r\nHELLO", manifest,
  )
  assert_false(mismatch.valid)
  assert_eq(mismatch.issues[0].code, "raw-sha256-mismatch")
}

///|
test "canonical sidecar verification detects changed recorded metadata" {
  let raw = b"Subject: original\r\n\r\nhello"
  let sidecar = @forensics.render_json(
    @forensics.build_manifest(raw, "case", "source"),
  )
  assert_true(@forensics.verify_sidecar(raw, sidecar, "case", "source").valid)
  assert_false(
    @forensics.verify_sidecar(raw, sidecar, "case", "other-source").valid,
  )
}

///|
test "untrusted attachment ranges never drive slicing during verification" {
  let raw = b"Content-Disposition: attachment; filename=data.bin\r\n\r\nabc"
  let original = @forensics.build_manifest(raw, "case", "source")
  let attachment = {
    ..original.attachments[0],
    body_start: -1,
    body_end: 2147483647,
    encoded_sha256: "forged",
  }
  let result = @forensics.verify_manifest(raw, {
    ..original,
    attachments: [attachment],
  })
  assert_false(result.valid)
  assert_true(result.issues.any(i => i.code == "attachment-range-invalid"))
  assert_true(result.issues.any(i => i.code == "attachment-sha256-mismatch"))
  assert_eq(original.attachments[0].body_start, 54)
}

///|
test "canonical sidecar permits terminal newline but rejects added JSON fields" {
  let raw = b"Subject: original\r\n\r\nhello"
  let sidecar = @forensics.render_json(
    @forensics.build_manifest(raw, "case", "source"),
  )
  assert_true(
    @forensics.verify_sidecar(raw, sidecar + "\r\n", "case", "source").valid,
  )
  assert_false(
    @forensics.verify_sidecar(raw, " " + sidecar, "case", "source").valid,
  )
  assert_false(
    @forensics.verify_sidecar(raw, sidecar + "{}", "case", "source").valid,
  )
}
