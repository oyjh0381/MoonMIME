///|
/// No body bytes are returned or extracted; ranges refer to the original input.
#derive(Eq, Debug)
pub(all) struct EntityFingerprint {
  path : Array[Int32]
  kind : String
  media_type : String
  filename : String?
  disposition : String?
  transfer_encoding : String
  body_range : @model.ByteRange
  encoded_sha256 : String
  decoded_sha256 : String?
  decoded_bytes : Int32?
  decode_status : String
  decode_error : String?
}

///|
#derive(Eq, Debug)
pub(all) struct PayloadInventory {
  raw_sha256 : String
  raw_bytes : Int32
  entities : Array[EntityFingerprint]
  diagnostics : Array[String]
  decoded_total : Int32
  complete : Bool
}

///|
/// Inventory every entity and decode supported leaf encodings under one shared
/// budget. Invalid/unknown/exhausted payloads remain explicitly unavailable;
/// their encoded hashes and source locations remain usable evidence.
pub fn observe(
  input : Bytes,
  mode~ : @model.ParseMode = @model.Strict,
  limits~ : @model.ResourceLimits = @model.ResourceLimits::secure_defaults(),
) -> PayloadInventory raise @model.MimeError {
  let message = @parser.parse_message(input, mode~, limits~)
  let budget = @transfer.DecodeBudget::new(limits)
  let fingerprints = []
  let mut complete = true
  for entity in @query.entities(message) {
    let wire = input[entity.body_range.start:entity.body_range.end].to_owned()
    let mut decoded_sha256 = None
    let mut decoded_bytes = None
    let mut status = "container"
    let mut failure = None
    if entity.kind == @model.EmbeddedMessage &&
      entity.children.is_empty() &&
      !wire.is_empty() {
      status = "opaque"
      failure = Some("MOONMIME_EMBEDDED_OPAQUE")
      complete = false
    } else if entity.kind == @model.Leaf {
      match entity.transfer_encoding {
        @model.Extension(_) => {
          status = "unsupported"
          complete = false
          failure = Some("MOONMIME_TRANSFER_UNSUPPORTED")
        }
        _ =>
          if wire.is_empty() {
            status = "decoded"
            decoded_sha256 = Some(@sha256.digest_hex(b""))
            decoded_bytes = Some(0)
          } else {
            try {
              let decoded = budget.decode_entity(message, entity, mode)
              status = if decoded.compatibility_recovery {
                "recovered"
              } else {
                "decoded"
              }
              decoded_sha256 = Some(@sha256.digest_hex(decoded.bytes))
              decoded_bytes = Some(decoded.bytes.length())
            } catch {
              error => {
                status = "unavailable"
                failure = Some(error.code())
                complete = false
              }
            }
          }
      }
    }
    fingerprints.push({
      path: entity.path.copy(),
      kind: match entity.kind {
        @model.Leaf => "leaf"
        @model.Multipart => "multipart"
        @model.EmbeddedMessage => "message"
      },
      media_type: entity.media_type.essence(),
      filename: entity.filename(),
      disposition: entity.disposition.map(d => d.kind),
      transfer_encoding: entity.transfer_encoding.to_string(),
      body_range: entity.body_range,
      encoded_sha256: @sha256.digest_hex(wire),
      decoded_sha256,
      decoded_bytes,
      decode_status: status,
      decode_error: failure,
    })
  }
  {
    raw_sha256: @sha256.digest_hex(input),
    raw_bytes: input.length(),
    entities: fingerprints,
    diagnostics: message.diagnostics.map(d => d.code.to_code()),
    decoded_total: budget.consumed,
    complete,
  }
}

///|
pub fn render_json(inventory : PayloadInventory) -> String {
  let entities : Array[Json] = inventory.entities.map(item => {
    "path": Json::array(item.path.map(n => Json::number(n.to_double()))),
    "kind": Json::string(item.kind),
    "media_type": Json::string(item.media_type),
    "filename": optional_json(item.filename),
    "disposition": optional_json(item.disposition),
    "transfer_encoding": Json::string(item.transfer_encoding),
    "body_start": Json::number(item.body_range.start.to_double()),
    "body_end": Json::number(item.body_range.end.to_double()),
    "encoded_sha256": Json::string(item.encoded_sha256),
    "decoded_sha256": optional_json(item.decoded_sha256),
    "decoded_bytes": match item.decoded_bytes {
      Some(n) => Json::number(n.to_double())
      None => Json::null()
    },
    "decode_status": Json::string(item.decode_status),
    "decode_error": optional_json(item.decode_error),
  })
  let output : Json = {
    "schema": Json::string("moonmime.inventory.v1"),
    "raw_sha256": Json::string(inventory.raw_sha256),
    "raw_bytes": Json::number(inventory.raw_bytes.to_double()),
    "entities": Json::array(entities),
    "diagnostics": Json::array(inventory.diagnostics.map(Json::string)),
    "decoded_total": Json::number(inventory.decoded_total.to_double()),
    "complete": Json::boolean(inventory.complete),
  }
  output.stringify()
}

///|
fn optional_json(value : String?) -> Json {
  match value {
    Some(text) => Json::string(text)
    None => Json::null()
  }
}

///|
pub extend EntityFingerprint with Eq::{not_equal, equal}

///|
pub extend EntityFingerprint with @debug.Debug::{to_repr}

///|
pub extend PayloadInventory with Eq::{not_equal, equal}

///|
pub extend PayloadInventory with @debug.Debug::{to_repr}
