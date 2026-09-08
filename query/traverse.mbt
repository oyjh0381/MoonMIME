///|
/// Return every entity in deterministic depth-first preorder.
pub fn entities(message : @model.InternetMessage) -> Array[@model.MimeEntity] {
  let output : Array[@model.MimeEntity] = []
  append_entity(output, message.root)
  output
}

///|
/// Resolve a stable numeric path such as `[1, 0]` into an entity.
pub fn find_entity(
  message : @model.InternetMessage,
  path : Array[Int],
) -> @model.MimeEntity? {
  let mut current = message.root
  for component in path {
    if component < 0 || component >= current.children.length() {
      return None
    }
    current = current.children[component]
  }
  Some(current)
}

///|
/// Enumerate attachment candidates without decoding or writing their bodies.
///
/// A leaf is considered an attachment when it has an explicit attachment
/// disposition or a filename/name parameter. Inline named resources therefore
/// remain discoverable, with `explicit=false` in their metadata.
pub fn attachments(message : @model.InternetMessage) -> Array[@model.Attachment] {
  let output : Array[@model.Attachment] = []
  for entity in entities(message) {
    if entity.kind != @model.Leaf {
      continue
    }
    let filename = entity.filename()
    let explicit = entity.is_explicit_attachment()
    if !explicit && filename is None {
      continue
    }
    let disposition = match entity.disposition {
      Some(value) => Some(value.kind)
      None => None
    }
    output.push({
      path: entity.path.copy(),
      filename,
      media_type: entity.media_type.essence(),
      disposition,
      transfer_encoding: entity.transfer_encoding.to_string(),
      raw_size: entity.body_range.length(),
      explicit,
    })
  }
  output
}

///|
fn append_entity(
  output : Array[@model.MimeEntity],
  entity : @model.MimeEntity,
) -> Unit {
  output.push(entity)
  for child in entity.children {
    append_entity(output, child)
  }
}
