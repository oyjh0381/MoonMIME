///|
test "gateway rules can quarantine a benign extension by declared media type" {
  let raw = b"Content-Type: application/pdf\r\nContent-Disposition: attachment; filename=invoice.pdf\r\n\r\nINERT"
  assert_eq(@gateway.evaluate(raw, "a").action, @gateway.Allow)
  let result = @gateway.evaluate_with_rules(raw, "a", {
    ..@gateway.GatewayRules::default(),
    blocked_media_types: ["application/pdf"],
  })
  assert_eq(result.decision.action, @gateway.Quarantine)
  assert_eq(result.policy_findings[0].code, "blocked-declared-media-type")
  assert_eq(result.policy_findings[0].entity_path, [])
}

///|
test "attachment metadata restrictions compose and retain source locations" {
  let raw = b"Content-Type: application/pdf\r\nContent-Disposition: attachment; filename=invoice.PDF\r\n\r\nINERT"
  let result = @gateway.evaluate_with_rules(raw, "source", {
    ..@gateway.GatewayRules::default(),
    allowed_media_types: Some(["image/png"]),
    blocked_filename_suffixes: [".pdf"],
    max_attachments: 0,
    max_attachment_wire_bytes: 4,
    max_total_attachment_wire_bytes: 4,
  })
  for
    code in [
      "undeclared-allowlist-media-type", "blocked-filename-suffix", "attachment-count-limit",
      "attachment-wire-size-limit", "attachment-total-wire-size-limit",
    ] {
    assert_true(result.policy_findings.any(f => f.code == code))
  }
  for finding in result.policy_findings {
    assert_true(finding.evidence_range.start >= 0)
    assert_true(finding.evidence_range.end <= raw.length())
  }
}

///|
test "custom policy cannot relax built in suspicious evidence" {
  let raw = b"Content-Disposition: attachment; filename=payload.exe\r\n\r\ninert"
  let assessment = @gateway.evaluate_with_rules(
    raw,
    "source",
    @gateway.GatewayRules::default(),
  )
  assert_true(assessment.policy_findings.is_empty())
  assert_eq(assessment.decision.action, @gateway.Quarantine)
}

///|
test "required attachment names reject an empty quoted filename" {
  let raw = b"Content-Disposition: attachment; filename=\"\"\r\n\r\ninert"
  let result = @gateway.evaluate_with_rules(raw, "source", {
    ..@gateway.GatewayRules::default(),
    require_attachment_names: true,
  })
  assert_true(
    result.policy_findings.any(f => f.code == "attachment-name-required"),
  )
}

///|
test "wildcard or uppercase media policy is rejected instead of silently misinterpreted" {
  for media_type in ["application/*", "Application/pdf", "application", "/pdf"] {
    let rejected = try {
      ignore(
        @gateway.evaluate_with_rules(b"\r\nhello", "source", {
          ..@gateway.GatewayRules::default(),
          blocked_media_types: [media_type],
        }),
      )
      false
    } catch {
      _ => true
    }
    assert_true(rejected)
  }
}
