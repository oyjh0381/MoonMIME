///|
// Independent module: no imports from internal packages, no attachment writes.
fn main raise {
  let attachment = b"Content-Type: application/pdf\r\nContent-Disposition: attachment; filename=invoice.pdf\r\nContent-Transfer-Encoding: base64\r\n\r\naGVsbG8="
  let benign = b"Subject: status\r\n\r\nhello"
  let rules = {
    ..@gateway.GatewayRules::default(),
    blocked_media_types: ["application/pdf"],
  }
  let batch = @gateway.evaluate_batch(
    [
      { source_id: "status", input: benign, },
      { source_id: "invoice", input: attachment, },
      { source_id: "damaged", input: b"not a header", },
    ],
    rules,
  )
  if batch.allowed != 1 || batch.quarantined != 1 || batch.rejected != 1 {
    abort("mailroom routing regression")
  }
  let inventory = @evidence.observe(attachment)
  if inventory.entities[0].decoded_sha256 !=
    Some("2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824") {
    abort("decoded evidence regression")
  }
  let sidecar = @forensics.render_json(
    @forensics.build_manifest(attachment, "demo-case", "invoice"),
  )
  if !@forensics.verify_sidecar(attachment, sidecar, "demo-case", "invoice").valid {
    abort("preserved evidence failed verification")
  }
  if @forensics.verify_sidecar(attachment, sidecar, "demo-case", "forged-label").valid {
    abort("changed source label accepted")
  }
  println(@gateway.batch_json(batch))
  println(@evidence.render_json(inventory))
  println(
    "mailroom consumer: allow=1 quarantine=1 reject=1; decoded SHA verified; tampered sidecar refused",
  )
}
