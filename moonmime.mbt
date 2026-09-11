///|
/// Parse with secure resource defaults and strict RFC-oriented behavior.
pub fn parse(input : Bytes) -> @model.InternetMessage raise @model.MimeError {
  @parser.parse_message(input)
}

///|
/// Parse with explicit recovery behavior and resource limits.
pub fn parse_with(
  input : Bytes,
  mode : @model.ParseMode,
  limits : @model.ResourceLimits,
) -> @model.InternetMessage raise @model.MimeError {
  @parser.parse_message(input, mode~, limits~)
}

///|
/// Parse and return the stable v1 JSON inspection report.
pub fn inspect_json(
  input : Bytes,
  mode? : @model.ParseMode = @model.Strict,
  limits? : @model.ResourceLimits = @model.ResourceLimits::secure_defaults(),
) -> String raise @model.MimeError {
  @report.render_json(@parser.parse_message(input, mode~, limits~))
}

///|
/// Parse and return the human-oriented entity summary.
pub fn inspect_text(
  input : Bytes,
  mode? : @model.ParseMode = @model.Strict,
  limits? : @model.ResourceLimits = @model.ResourceLimits::secure_defaults(),
) -> String raise @model.MimeError {
  @report.render_summary(@parser.parse_message(input, mode~, limits~))
}

///|
/// Parse and audit untrusted message structure without decoding attachments.
pub fn audit(
  input : Bytes,
  mode? : @model.ParseMode = @model.Compatible,
  limits? : @model.ResourceLimits = @model.ResourceLimits::secure_defaults(),
) -> @audit.AuditReport raise @model.MimeError {
  @audit.audit_message(@parser.parse_message(input, mode~, limits~))
}

///|
/// Parse and return stable `moonmime.audit.v1` JSON for security pipelines.
pub fn audit_json(
  input : Bytes,
  mode? : @model.ParseMode = @model.Compatible,
  limits? : @model.ResourceLimits = @model.ResourceLimits::secure_defaults(),
) -> String raise @model.MimeError {
  @audit.render_json(audit(input, mode~, limits~))
}

///|
/// Decode a selected entity body after validating its source range.
pub fn decode_body(
  message : @model.InternetMessage,
  path : Array[Int],
  mode? : @model.ParseMode = @model.Strict,
  max_output? : Int = 16 * 1024 * 1024,
) -> Bytes raise @model.MimeError {
  let entity = match @query.find_entity(message, path) {
    Some(value) => value
    None => raise @model.InvalidArgument("entity path does not exist")
  }
  if entity.kind != @model.Leaf {
    raise @model.InvalidArgument("only leaf entity bodies can be decoded")
  }
  @transfer.decode_entity_body(message, entity, mode, max_output~).bytes
}

///|
/// Re-export the secure default limits through the root package.
pub fn secure_limits() -> @model.ResourceLimits {
  @model.ResourceLimits::secure_defaults()
}

///|
/// Re-export the smaller edge-oriented limits through the root package.
pub fn edge_limits() -> @model.ResourceLimits {
  @model.ResourceLimits::edge_defaults()
}
