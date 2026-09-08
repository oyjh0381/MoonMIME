///|
/// Ordered media parameter preserving its original name and decoded value.
pub(all) struct MediaParameter {
  name : String
  lower_name : String
  value : String
  extended : Bool
  section : Int?
  encoded : Bool
} derive(Debug, Eq)

///|
/// Parsed MIME media type and ordered parameters.
pub(all) struct MediaType {
  top_level : String
  subtype : String
  parameters : Array[MediaParameter]
} derive(Debug, Eq)

///|
/// Default media type for a MIME entity with no Content-Type field.
pub fn MediaType::text_plain() -> MediaType {
  { top_level: "text", subtype: "plain", parameters: [] }
}

///|
/// Lowercase `type/subtype` spelling.
pub fn MediaType::essence(self : MediaType) -> String {
  self.top_level + "/" + self.subtype
}

///|
/// Whether this media type is a multipart container.
pub fn MediaType::is_multipart(self : MediaType) -> Bool {
  self.top_level == "multipart"
}

///|
/// Whether this entity carries an embedded Internet Message.
pub fn MediaType::is_message_rfc822(self : MediaType) -> Bool {
  self.top_level == "message" && self.subtype == "rfc822"
}

///|
/// Return the last parameter with a normalized name.
pub fn MediaType::parameter(
  self : MediaType,
  lower_name : StringView,
) -> String? {
  let wanted = lower_name.to_owned()
  let mut result : String? = None
  for parameter in self.parameters {
    if parameter.lower_name == wanted {
      result = Some(parameter.value)
    }
  }
  result
}

///|
/// Content-Disposition and its ordered parameters.
pub(all) struct ContentDisposition {
  kind : String
  parameters : Array[MediaParameter]
} derive(Debug, Eq)

///|
/// Return the last parameter with a normalized name.
pub fn ContentDisposition::parameter(
  self : ContentDisposition,
  lower_name : StringView,
) -> String? {
  let wanted = lower_name.to_owned()
  let mut result : String? = None
  for parameter in self.parameters {
    if parameter.lower_name == wanted {
      result = Some(parameter.value)
    }
  }
  result
}

///|
/// Standard and extension content-transfer encodings.
pub(all) enum TransferEncoding {
  SevenBit
  EightBit
  Binary
  Base64
  QuotedPrintable
  Extension(String)
} derive(Debug, Eq)

///|
/// Canonical lower-case spelling for reports.
pub fn TransferEncoding::to_string(self : TransferEncoding) -> String {
  match self {
    SevenBit => "7bit"
    EightBit => "8bit"
    Binary => "binary"
    Base64 => "base64"
    QuotedPrintable => "quoted-printable"
    Extension(value) => value
  }
}
