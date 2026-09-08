///|
/// One ordered header field with normalized lookup name and unfolded value.
pub(all) struct HeaderField {
  name : String
  lower_name : String
  value : String
  field_range : ByteRange
  value_range : ByteRange
  line_count : Int
} derive(Debug, Eq)

///|
/// Ordered fields and their exact source region.
pub(all) struct HeaderBlock {
  fields : Array[HeaderField]
  range : ByteRange
  body_start : Int
} derive(Debug, Eq)

///|
/// Return the first field whose name matches ASCII case-insensitively.
pub fn HeaderBlock::first(self : HeaderBlock, lower_name : StringView) -> HeaderField? {
  let wanted = lower_name.to_owned()
  for field in self.fields {
    if field.lower_name == wanted {
      return Some(field)
    }
  }
  None
}

///|
/// Return every matching field without losing original order.
pub fn HeaderBlock::all(
  self : HeaderBlock,
  lower_name : StringView,
) -> Array[HeaderField] {
  let wanted = lower_name.to_owned()
  let output : Array[HeaderField] = []
  for field in self.fields {
    if field.lower_name == wanted {
      output.push(field)
    }
  }
  output
}

///|
/// Whether at least one field with the requested normalized name exists.
pub fn HeaderBlock::contains(self : HeaderBlock, lower_name : StringView) -> Bool {
  self.first(lower_name) is Some(_)
}
