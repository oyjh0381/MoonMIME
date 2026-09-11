///|
/// Render a concise report for an analyst or CI log.
pub fn render_summary(report : AuditReport) -> String {
  let builder = StringBuilder()
  builder.write_string("MoonMIME security audit\n")
  builder.write_string("risk-score: " + report.risk_score.to_string() + "/100\n")
  builder.write_string("high: " + report.high.to_string() + "\n")
  builder.write_string("medium: " + report.medium.to_string() + "\n")
  builder.write_string("low: " + report.low.to_string() + "\n")
  builder.write_string("info: " + report.info.to_string() + "\n")
  for finding in report.findings {
    builder.write_string(
      "[" + finding.severity.to_string() + "] " + finding.code.to_code() +
      " entity=" + render_path(finding.entity_path) + " bytes=" +
      finding.evidence_range.start.to_string() + ".." +
      finding.evidence_range.end.to_string() + " " + finding.message + "\n",
    )
  }
  builder.to_string()
}

///|
/// Render the stable `moonmime.audit.v1` exchange format.
pub fn render_json(report : AuditReport) -> String {
  let builder = StringBuilder()
  builder.write_string("{\"schema\":\"moonmime.audit.v1\",\"risk_score\":")
  builder.write_string(report.risk_score.to_string())
  builder.write_string(",\"counts\":{\"high\":")
  builder.write_string(report.high.to_string())
  builder.write_string(",\"medium\":")
  builder.write_string(report.medium.to_string())
  builder.write_string(",\"low\":")
  builder.write_string(report.low.to_string())
  builder.write_string(",\"info\":")
  builder.write_string(report.info.to_string())
  builder.write_string("},\"findings\":[")
  for index in 0..<report.findings.length() {
    if index > 0 {
      builder.write_char(',')
    }
    let finding = report.findings[index]
    builder.write_string("{\"code\":\"")
    builder.write_string(finding.code.to_code())
    builder.write_string("\",\"severity\":\"")
    builder.write_string(finding.severity.to_string())
    builder.write_string("\",\"entity_path\":[")
    for component_index in 0..<finding.entity_path.length() {
      if component_index > 0 {
        builder.write_char(',')
      }
      builder.write_string(finding.entity_path[component_index].to_string())
    }
    builder.write_string("],\"start\":")
    builder.write_string(finding.evidence_range.start.to_string())
    builder.write_string(",\"end\":")
    builder.write_string(finding.evidence_range.end.to_string())
    builder.write_string(",\"message\":\"")
    write_json_text(builder, finding.message)
    builder.write_string("\"}")
  }
  builder.write_string("]}")
  builder.to_string()
}

///|
fn render_path(path : Array[Int]) -> String {
  if path.is_empty() {
    return "."
  }
  let builder = StringBuilder()
  for index in 0..<path.length() {
    if index > 0 {
      builder.write_char('.')
    }
    builder.write_string(path[index].to_string())
  }
  builder.to_string()
}

///|
fn write_json_text(builder : StringBuilder, value : String) -> Unit {
  for byte in @utf8.encode(value) {
    match byte {
      b'"' => builder.write_string("\\\"")
      b'\\' => builder.write_string("\\\\")
      b'\n' => builder.write_string("\\n")
      b'\r' => builder.write_string("\\r")
      b'\t' => builder.write_string("\\t")
      _ => builder.write_char(byte.to_int().unsafe_to_char())
    }
  }
}

