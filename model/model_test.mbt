///|
test "secure resource defaults are internally valid" {
  let limits = ResourceLimits::secure_defaults()
  limits.validate()
  assert_eq(limits.max_depth, 16)
  assert_eq(limits.max_entities, 1000)
  assert_true(limits.max_total_decoded_bytes >= limits.max_decoded_leaf_bytes)
}

///|
test "edge defaults are stricter than secure defaults" {
  let secure = ResourceLimits::secure_defaults()
  let edge = ResourceLimits::edge_defaults()
  edge.validate()
  assert_true(edge.max_input_bytes < secure.max_input_bytes)
  assert_true(edge.max_entities < secure.max_entities)
}

///|
test "byte ranges use half-open bounds" {
  let range = ByteRange::new(2, 5)
  assert_eq(range.length(), 3)
  assert_true(range.contains(2))
  assert_true(range.contains(4))
  assert_false(range.contains(5))
  range.validate(5)
}

///|
test "header lookup preserves duplicates and order" {
  let first : HeaderField = {
    name: "Received",
    lower_name: "received",
    value: "one",
    field_range: ByteRange::trusted(0, 10),
    value_range: ByteRange::trusted(9, 10),
    line_count: 1,
  }
  let second : HeaderField = {
    name: "received",
    lower_name: "received",
    value: "two",
    field_range: ByteRange::trusted(11, 21),
    value_range: ByteRange::trusted(20, 21),
    line_count: 1,
  }
  let block : HeaderBlock = {
    fields: [first, second],
    range: ByteRange::trusted(0, 23),
    body_start: 23,
  }
  assert_eq(block.first("received").unwrap().value, "one")
  assert_eq(block.all("received").map(field => field.value), ["one", "two"])
}

///|
test "media helpers expose normalized semantics" {
  let media : MediaType = {
    top_level: "multipart",
    subtype: "mixed",
    parameters: [
      {
        name: "boundary",
        lower_name: "boundary",
        value: "outer",
        extended: false,
        section: None,
        encoded: false,
      },
    ],
  }
  assert_eq(media.essence(), "multipart/mixed")
  assert_true(media.is_multipart())
  assert_eq(media.parameter("boundary"), Some("outer"))
}

///|
test "error categories remain machine stable" {
  let error : MimeError = InvalidBase64(12, "bad alphabet")
  assert_eq(error.code(), "MOONMIME_BASE64")
  assert_eq(error.exit_code(), 4)
  assert_true(error.message().contains("byte 12"))
}
