///|
/// Structural interpretation of one MIME Entity body.
#derive(Debug, Eq)
pub(all) enum EntityKind {
  Leaf
  Multipart
  EmbeddedMessage
}

///|
/// One byte-preserving entity in the recursive MIME tree.
#derive(Debug, Eq)
pub(all) struct MimeEntity {
  path : Array[Int32]
  depth : Int32
  headers : HeaderBlock
  media_type : MediaType
  disposition : ContentDisposition?
  transfer_encoding : TransferEncoding
  kind : EntityKind
  entity_range : ByteRange
  body_range : ByteRange
  preamble_range : ByteRange?
  epilogue_range : ByteRange?
  children : Array[MimeEntity]
}

///|
/// Whether Content-Disposition explicitly marks this entity as an attachment.
pub fn MimeEntity::is_explicit_attachment(self : MimeEntity) -> Bool {
  match self.disposition {
    Some(value) => value.kind == "attachment"
    None => false
  }
}

///|
/// Filename parameter without applying filesystem path semantics.
pub fn MimeEntity::filename(self : MimeEntity) -> String? {
  match self.disposition {
    Some(value) => value.parameter("filename")
    None => self.media_type.parameter("name")
  }
}

///|
/// Full parsed message, retaining exact input bytes and all diagnostics.
#derive(Debug, Eq)
pub(all) struct InternetMessage {
  raw : Bytes
  root : MimeEntity
  diagnostics : Array[ParseDiagnostic]
  stats : ParseStats
}

///|
/// Counts accumulated without re-walking the entity tree.
#derive(Debug, Eq)
pub(all) struct ParseStats {
  entities : Int32
  leaf_entities : Int32
  multipart_entities : Int32
  embedded_messages : Int32
  maximum_depth : Int32
  raw_bytes : Int32
}

///|
/// Metadata returned when enumerating attachment candidates.
#derive(Debug, Eq)
pub(all) struct Attachment {
  path : Array[Int32]
  filename : String?
  media_type : String
  disposition : String?
  transfer_encoding : String
  raw_size : Int32
  explicit : Bool
}

///|
/// Selected display-body candidate.
#derive(Debug, Eq)
pub(all) struct TextSelection {
  path : Array[Int32]
  media_type : String
  charset : String?
  text : String
}

///|
pub extend EntityKind with @debug.Debug::{to_repr}

///|
pub extend EntityKind with Eq::{not_equal, equal}

///|
pub extend MimeEntity with @debug.Debug::{to_repr}

///|
pub extend MimeEntity with Eq::{not_equal, equal}

///|
pub extend InternetMessage with @debug.Debug::{to_repr}

///|
pub extend InternetMessage with Eq::{not_equal, equal}

///|
pub extend ParseStats with @debug.Debug::{to_repr}

///|
pub extend ParseStats with Eq::{not_equal, equal}

///|
pub extend Attachment with @debug.Debug::{to_repr}

///|
pub extend Attachment with Eq::{not_equal, equal}

///|
pub extend TextSelection with @debug.Debug::{to_repr}

///|
pub extend TextSelection with Eq::{not_equal, equal}
