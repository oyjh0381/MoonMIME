///|
/// Structural interpretation of one MIME Entity body.
pub(all) enum EntityKind {
  Leaf
  Multipart
  EmbeddedMessage
} derive(Debug, Eq)

///|
/// One byte-preserving entity in the recursive MIME tree.
pub(all) struct MimeEntity {
  path : Array[Int]
  depth : Int
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
} derive(Debug, Eq)

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
pub(all) struct InternetMessage {
  raw : Bytes
  root : MimeEntity
  diagnostics : Array[ParseDiagnostic]
  stats : ParseStats
} derive(Debug, Eq)

///|
/// Counts accumulated without re-walking the entity tree.
pub(all) struct ParseStats {
  entities : Int
  leaf_entities : Int
  multipart_entities : Int
  embedded_messages : Int
  maximum_depth : Int
  raw_bytes : Int
} derive(Debug, Eq)

///|
/// Metadata returned when enumerating attachment candidates.
pub(all) struct Attachment {
  path : Array[Int]
  filename : String?
  media_type : String
  disposition : String?
  transfer_encoding : String
  raw_size : Int
  explicit : Bool
} derive(Debug, Eq)

///|
/// Selected display-body candidate.
pub(all) struct TextSelection {
  path : Array[Int]
  media_type : String
  charset : String?
  text : String
} derive(Debug, Eq)

