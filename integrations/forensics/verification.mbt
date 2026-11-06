///|
pub(all) struct ManifestIssue {
  code : String
  attachment_index : Int32?
} derive(Eq, Debug)

///|
pub(all) struct ManifestVerification {
  valid : Bool
  checked_attachments : Int32
  issues : Array[ManifestIssue]
} derive(Eq, Debug)

///|
/// Reparse and recompute against the supplied original bytes. Case/source IDs
/// are caller assertions, not authenticated provenance. This verifies our v1
/// manifest semantics, not a signature or the truth of external acquisition.
pub fn verify_manifest(
  input : Bytes,
  manifest : EvidenceManifest,
  limits~ : @model.ResourceLimits = @model.ResourceLimits::secure_defaults(),
) -> ManifestVerification raise @model.MimeError {
  limits.validate()
  if input.length() > limits.max_input_bytes {
    raise @model.InputTooLarge(input.length(), limits.max_input_bytes)
  }
  require_identifier(manifest.case_id, "case_id")
  require_identifier(manifest.source_id, "source_id")
  if manifest.attachments.length() > limits.max_entities ||
    manifest.audit.findings.length().to_int64() >
    limits.max_entities.to_int64() * 8L + limits.max_diagnostics.to_int64() {
    raise @model.InvalidArgument(
      "manifest evidence count exceeds parser profile",
    )
  }
  let issues : Array[ManifestIssue] = []
  if input.length() != manifest.raw_bytes {
    issues.push({ code: "raw-size-mismatch", attachment_index: None, })
  }
  if @sha256.digest_hex(input) != manifest.raw_sha256 {
    issues.push({ code: "raw-sha256-mismatch", attachment_index: None, })
  }
  if !issues.is_empty() {
    return { valid: false, checked_attachments: 0, issues, }
  }
  let actual = build_manifest(
    input,
    manifest.case_id,
    manifest.source_id,
    limits~,
  )
  if actual.entity_count != manifest.entity_count ||
    actual.message_id != manifest.message_id ||
    actual.subject != manifest.subject {
    issues.push({ code: "message-metadata-mismatch", attachment_index: None, })
  }
  if actual.attachments.length() != manifest.attachments.length() {
    issues.push({ code: "attachment-count-mismatch", attachment_index: None, })
  }
  let count = actual.attachments.length().min(manifest.attachments.length())
  for i in 0..<count {
    let expected = actual.attachments[i]
    let declared = manifest.attachments[i]
    if declared.body_start < 0 ||
      declared.body_end < declared.body_start ||
      declared.body_end > input.length() {
      issues.push({
        code: "attachment-range-invalid",
        attachment_index: Some(i),
      })
    } else if expected.body_start != declared.body_start ||
      expected.body_end != declared.body_end {
      issues.push({
        code: "attachment-range-mismatch",
        attachment_index: Some(i),
      })
    }
    if expected.encoded_sha256 != declared.encoded_sha256 {
      issues.push({
        code: "attachment-sha256-mismatch",
        attachment_index: Some(i),
      })
    }
    if expected.entity_path != declared.entity_path ||
      expected.filename != declared.filename ||
      expected.media_type != declared.media_type {
      issues.push({
        code: "attachment-metadata-mismatch",
        attachment_index: Some(i),
      })
    }
  }
  if actual.audit != manifest.audit {
    issues.push({ code: "audit-mismatch", attachment_index: None, })
  }
  { valid: issues.is_empty(), checked_attachments: count, issues, }
}

///|
/// Verify the exact canonical v1 serialization produced by render_json.
/// One terminal LF/CRLF is allowed for CLI output. Alternative JSON layouts,
/// duplicate keys and unknown fields are not accepted as equivalent evidence.
/// IDs are supplied separately so a changed sidecar cannot choose its own label.
pub fn verify_sidecar(
  input : Bytes,
  sidecar : String,
  case_id : String,
  source_id : String,
  limits~ : @model.ResourceLimits = @model.ResourceLimits::secure_defaults(),
) -> ManifestVerification raise @model.MimeError {
  if sidecar.length() > 16777216 {
    raise @model.InvalidArgument("sidecar exceeds 16 Mi UTF-16 units")
  }
  let actual = build_manifest(input, case_id, source_id, limits~)
  let canonical = render_json(actual)
  let valid = sidecar == canonical ||
    sidecar == canonical + "\n" ||
    sidecar == canonical + "\r\n"
  {
    valid,
    checked_attachments: if valid {
      actual.attachments.length()
    } else {
      0
    },
    issues: if valid {
      []
    } else {
      [{ code: "canonical-sidecar-mismatch", attachment_index: None, }]
    },
  }
}

///|
pub fn verification_json(result : ManifestVerification) -> String {
  let issues : Array[Json] = result.issues.map(issue => {
    "code": Json::string(issue.code),
    "attachment_index": match issue.attachment_index {
      Some(i) => Json::number(i.to_double())
      None => Json::null()
    },
  })
  let output : Json = {
    "schema": Json::string("moonmime.verification.v1"),
    "valid": Json::boolean(result.valid),
    "checked_attachments": Json::number(result.checked_attachments.to_double()),
    "issues": Json::array(issues),
  }
  output.stringify()
}

///|
pub extend ManifestIssue with Eq::{not_equal, equal}

///|
pub extend ManifestIssue with @debug.Debug::{to_repr}

///|
pub extend ManifestVerification with Eq::{not_equal, equal}

///|
pub extend ManifestVerification with @debug.Debug::{to_repr}
