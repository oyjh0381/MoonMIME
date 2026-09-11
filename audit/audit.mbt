///|
/// Severity of a security or forensic audit finding.
pub(all) enum AuditSeverity {
  Info
  Low
  Medium
  High
} derive(Debug, Eq)

///|
/// Machine-stable finding categories. These codes are part of the public API.
pub(all) enum AuditCode {
  DuplicateSingletonHeader
  ConflictingSingletonHeader
  UnsafeAttachmentFilename
  ExecutableAttachmentName
  NestedBoundaryReuse
  OpaqueEmbeddedMessage
  ParserRecovery
  NonCanonicalLineEnding
} derive(Debug, Eq)

///|
/// One evidence-backed observation tied to an entity and source byte range.
pub(all) struct AuditFinding {
  code : AuditCode
  severity : AuditSeverity
  message : String
  entity_path : Array[Int]
  evidence_range : @model.ByteRange
} derive(Debug, Eq)

///|
/// Deterministic audit result suitable for CI policy decisions.
pub(all) struct AuditReport {
  findings : Array[AuditFinding]
  risk_score : Int
  high : Int
  medium : Int
  low : Int
  info : Int
} derive(Debug, Eq)

///|
/// Audit a parsed message without decoding bodies or writing attachments.
/// The checks target parser-differential and unsafe-extraction primitives;
/// they do not claim to classify spam or malware.
pub fn audit_message(message : @model.InternetMessage) -> AuditReport {
  let findings : Array[AuditFinding] = []
  audit_entity(message.root, [], findings)
  for diagnostic in message.diagnostics {
    match diagnostic.code {
      @model.BareLineFeed | @model.BareCarriageReturn =>
        findings.push({
          code: NonCanonicalLineEnding,
          severity: Medium,
          message: "non-canonical line ending can change parser boundaries",
          entity_path: diagnostic.entity_path.copy(),
          evidence_range: diagnostic.range,
        })
      _ =>
        findings.push({
          code: ParserRecovery,
          severity: Low,
          message: "compatible parsing recovered non-canonical syntax: " +
            diagnostic.code.to_code(),
          entity_path: diagnostic.entity_path.copy(),
          evidence_range: diagnostic.range,
        })
    }
  }
  summarize(findings)
}

///|
pub fn AuditReport::has_at_least(
  self : AuditReport,
  threshold : AuditSeverity,
) -> Bool {
  match threshold {
    High => self.high > 0
    Medium => self.high + self.medium > 0
    Low => self.high + self.medium + self.low > 0
    Info => !self.findings.is_empty()
  }
}

///|
pub fn AuditSeverity::to_string(self : AuditSeverity) -> String {
  match self {
    Info => "info"
    Low => "low"
    Medium => "medium"
    High => "high"
  }
}

///|
pub fn AuditCode::to_code(self : AuditCode) -> String {
  match self {
    DuplicateSingletonHeader => "duplicate-singleton-header"
    ConflictingSingletonHeader => "conflicting-singleton-header"
    UnsafeAttachmentFilename => "unsafe-attachment-filename"
    ExecutableAttachmentName => "executable-attachment-name"
    NestedBoundaryReuse => "nested-boundary-reuse"
    OpaqueEmbeddedMessage => "opaque-embedded-message"
    ParserRecovery => "parser-recovery"
    NonCanonicalLineEnding => "non-canonical-line-ending"
  }
}

///|
fn audit_entity(
  entity : @model.MimeEntity,
  ancestor_boundaries : Array[String],
  findings : Array[AuditFinding],
) -> Unit {
  for name in singleton_names() {
    audit_singleton(entity, name, findings)
  }
  match entity.filename() {
    Some(filename) => audit_filename(entity, filename, findings)
    None => ()
  }
  let child_boundaries = ancestor_boundaries.copy()
  if entity.media_type.is_multipart() {
    match entity.media_type.parameter("boundary") {
      Some(boundary) => {
        for ancestor in ancestor_boundaries {
          if boundary == ancestor {
            findings.push({
              code: NestedBoundaryReuse,
              severity: High,
              message: "nested multipart reuses an ancestor boundary",
              entity_path: entity.path.copy(),
              evidence_range: entity.headers.range,
            })
          }
        }
        child_boundaries.push(boundary)
      }
      None => ()
    }
  }
  if entity.kind == @model.EmbeddedMessage && entity.children.is_empty() {
    findings.push({
      code: OpaqueEmbeddedMessage,
      severity: Medium,
      message: "encoded message/rfc822 body was not structurally inspected",
      entity_path: entity.path.copy(),
      evidence_range: entity.body_range,
    })
  }
  for child in entity.children {
    audit_entity(child, child_boundaries, findings)
  }
}

///|
fn singleton_names() -> Array[String] {
  [
    "content-type",
    "content-disposition",
    "content-transfer-encoding",
    "mime-version",
    "subject",
    "from",
    "sender",
    "reply-to",
    "message-id",
  ]
}

///|
fn audit_singleton(
  entity : @model.MimeEntity,
  name : String,
  findings : Array[AuditFinding],
) -> Unit {
  let fields = entity.headers.all(name)
  if fields.length() <= 1 {
    return
  }
  let first = fields[0].value
  let mut conflicting = false
  for index in 1..<fields.length() {
    if fields[index].value != first {
      conflicting = true
    }
  }
  findings.push({
    code: if conflicting { ConflictingSingletonHeader } else { DuplicateSingletonHeader },
    severity: if conflicting { High } else { Medium },
    message: if conflicting {
      "conflicting " + name + " fields can produce parser disagreement"
    } else {
      "duplicate " + name + " field has ambiguous ownership"
    },
    entity_path: entity.path.copy(),
    evidence_range: fields[1].field_range,
  })
}

///|
fn audit_filename(
  entity : @model.MimeEntity,
  filename : String,
  findings : Array[AuditFinding],
) -> Unit {
  let bytes = @utf8.encode(filename)
  let mut suspicious = filename == "." || filename == ".."
  for byte in bytes {
    if byte == b'/' || byte == b'\\' || byte == b':' || byte < b' ' ||
      byte == b'\x7f' {
      suspicious = true
    }
  }
  if suspicious || filename.contains("../") || filename.contains("..\\") {
    findings.push({
      code: UnsafeAttachmentFilename,
      severity: High,
      message: "attachment filename contains path or control semantics",
      entity_path: entity.path.copy(),
      evidence_range: entity.headers.range,
    })
  }
  let lower = ascii_lower(filename)
  for suffix in executable_suffixes() {
    if lower.has_suffix(suffix) {
      findings.push({
        code: ExecutableAttachmentName,
        severity: Medium,
        message: "attachment uses an executable or script filename suffix",
        entity_path: entity.path.copy(),
        evidence_range: entity.headers.range,
      })
      return
    }
  }
}

///|
fn executable_suffixes() -> Array[String] {
  [".exe", ".com", ".bat", ".cmd", ".ps1", ".js", ".vbs", ".scr", ".msi"]
}

///|
fn ascii_lower(value : String) -> String {
  let bytes = @utf8.encode(value)
  let output : Array[Byte] = []
  for byte in bytes {
    if byte >= b'A' && byte <= b'Z' {
      output.push((byte.to_int() + 32).to_byte())
    } else {
      output.push(byte)
    }
  }
  @utf8.decode(Bytes::from_array(output)) catch { _ => value }
}

///|
fn summarize(findings : Array[AuditFinding]) -> AuditReport {
  let mut high = 0
  let mut medium = 0
  let mut low = 0
  let mut info = 0
  let mut score = 0
  for finding in findings {
    match finding.severity {
      High => { high = high + 1; score = score + 25 }
      Medium => { medium = medium + 1; score = score + 10 }
      Low => { low = low + 1; score = score + 3 }
      Info => info = info + 1
    }
  }
  if score > 100 {
    score = 100
  }
  { findings, risk_score: score, high, medium, low, info, }
}
