///|
pub(all) struct GatewayInput {
  source_id : String
  input : Bytes
}

///|
pub(all) struct BatchDecision {
  source_id : String
  assessment : GatewayAssessment?
  error_code : String?
  error_message : String?
}

///|
pub(all) struct GatewayBatch {
  results : Array[BatchDecision]
  allowed : Int32
  quarantined : Int32
  rejected : Int32
  input_bytes : Int64
}

///|
/// Preflight batch-wide quotas and unique source IDs before parsing anything.
/// Configuration errors raise; individual malformed inputs yield reject rows.
/// No actual queue/filesystem mutation or cross-call session state is retained.
pub fn evaluate_batch(
  inputs : Array[GatewayInput],
  rules : GatewayRules,
  policy~ : GatewayPolicy = GatewayPolicy::recommended(),
  max_messages~ : Int32 = 256,
  max_total_input_bytes~ : Int64 = 67108864L,
) -> GatewayBatch raise @model.MimeError {
  validate_rules(rules)
  policy.limits.validate()
  if max_messages < 1 ||
    max_messages > 10000 ||
    inputs.length() > max_messages ||
    max_total_input_bytes < 1L ||
    max_total_input_bytes > 1073741824L {
    raise @model.InvalidArgument("invalid or exceeded gateway batch quota")
  }
  let ids : Map[String, Bool] = Map([])
  let mut bytes = 0L
  for item in inputs {
    if item.source_id.trim().is_empty() ||
      item.source_id.length() > 1024 ||
      ids.contains(item.source_id) {
      raise @model.InvalidArgument(
        "batch source IDs must be unique and 1..1024 units",
      )
    }
    ids[item.source_id] = true
    bytes += item.input.length().to_int64()
    if bytes > max_total_input_bytes {
      raise @model.InvalidArgument("gateway batch input byte quota exceeded")
    }
  }
  let results = []
  let mut allowed = 0
  let mut quarantined = 0
  let mut rejected = 0
  for item in inputs {
    let row : BatchDecision = try {
      let result = evaluate_with_rules(
        item.input,
        item.source_id,
        rules,
        policy~,
      )
      match result.decision.action {
        Allow => allowed += 1
        Quarantine => quarantined += 1
      }
      {
        source_id: item.source_id,
        assessment: Some(result),
        error_code: None,
        error_message: None,
      }
    } catch {
      error => {
        rejected += 1
        {
          source_id: item.source_id,
          assessment: None,
          error_code: Some(error.code()),
          error_message: Some(error.message()),
        }
      }
    }
    results.push(row)
  }
  { results, allowed, quarantined, rejected, input_bytes: bytes, }
}

///|
pub fn batch_json(result : GatewayBatch) -> String {
  let rows = result.results.map(row => {
    let source : Json = Json::string(row.source_id)
    let body = match row.assessment {
      Some(value) => assessment_json(value)
      None =>
        render_error_json(
          row.source_id,
          row.error_message.unwrap_or("rejected"),
        )
    }
    "{\"source_id\":" +
    source.stringify() +
    ",\"result\":" +
    body +
    ",\"error_code\":" +
    (match row.error_code {
      Some(code) => Json::string(code).stringify()
      None => "null"
    }) +
    "}"
  })
  "{\"schema\":\"moonmime.batch.v1\",\"allowed\":" +
  result.allowed.to_string() +
  ",\"quarantined\":" +
  result.quarantined.to_string() +
  ",\"rejected\":" +
  result.rejected.to_string() +
  ",\"input_bytes\":" +
  result.input_bytes.to_string() +
  ",\"results\":[" +
  rows.join(",") +
  "]}"
}
