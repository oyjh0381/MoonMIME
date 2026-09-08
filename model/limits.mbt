///|
/// Resource limits applied before allocating or recursively parsing content.
pub(all) struct ResourceLimits {
  max_input_bytes : Int
  max_header_bytes : Int
  max_header_line_bytes : Int
  max_header_count : Int
  max_depth : Int
  max_entities : Int
  max_leaf_body_bytes : Int
  max_decoded_leaf_bytes : Int
  max_total_decoded_bytes : Int
  max_parameter_count : Int
  max_boundary_bytes : Int
  max_diagnostics : Int
} derive(Debug, Eq)

///|
/// Conservative defaults suitable for untrusted messages in ordinary tools.
pub fn ResourceLimits::secure_defaults() -> ResourceLimits {
  {
    max_input_bytes: 32 * 1024 * 1024,
    max_header_bytes: 256 * 1024,
    max_header_line_bytes: 998,
    max_header_count: 256,
    max_depth: 16,
    max_entities: 1000,
    max_leaf_body_bytes: 16 * 1024 * 1024,
    max_decoded_leaf_bytes: 16 * 1024 * 1024,
    max_total_decoded_bytes: 64 * 1024 * 1024,
    max_parameter_count: 128,
    max_boundary_bytes: 70,
    max_diagnostics: 256,
  }
}

///|
/// Tighter settings for small webhook or edge-function payloads.
pub fn ResourceLimits::edge_defaults() -> ResourceLimits {
  {
    max_input_bytes: 4 * 1024 * 1024,
    max_header_bytes: 64 * 1024,
    max_header_line_bytes: 998,
    max_header_count: 128,
    max_depth: 8,
    max_entities: 128,
    max_leaf_body_bytes: 2 * 1024 * 1024,
    max_decoded_leaf_bytes: 2 * 1024 * 1024,
    max_total_decoded_bytes: 8 * 1024 * 1024,
    max_parameter_count: 64,
    max_boundary_bytes: 70,
    max_diagnostics: 128,
  }
}

///|
/// Validate limit relationships before parsing attacker-controlled input.
pub fn ResourceLimits::validate(self : ResourceLimits) -> Unit raise MimeError {
  let values = [
    ("max_input_bytes", self.max_input_bytes),
    ("max_header_bytes", self.max_header_bytes),
    ("max_header_line_bytes", self.max_header_line_bytes),
    ("max_header_count", self.max_header_count),
    ("max_depth", self.max_depth),
    ("max_entities", self.max_entities),
    ("max_leaf_body_bytes", self.max_leaf_body_bytes),
    ("max_decoded_leaf_bytes", self.max_decoded_leaf_bytes),
    ("max_total_decoded_bytes", self.max_total_decoded_bytes),
    ("max_parameter_count", self.max_parameter_count),
    ("max_boundary_bytes", self.max_boundary_bytes),
    ("max_diagnostics", self.max_diagnostics),
  ]
  for item in values {
    let (name, value) = item
    if value <= 0 {
      raise InvalidArgument(name + " must be greater than zero")
    }
  }
  if self.max_header_bytes > self.max_input_bytes {
    raise InvalidArgument("max_header_bytes must not exceed max_input_bytes")
  }
  if self.max_leaf_body_bytes > self.max_input_bytes {
    raise InvalidArgument("max_leaf_body_bytes must not exceed max_input_bytes")
  }
  if self.max_decoded_leaf_bytes > self.max_total_decoded_bytes {
    raise InvalidArgument(
      "max_decoded_leaf_bytes must not exceed max_total_decoded_bytes",
    )
  }
}
