///|
/// Mutable decoded-output budget shared across a sequence of leaf decodes.
pub(all) struct DecodeBudget {
  per_leaf_limit : Int
  total_limit : Int
  mut consumed : Int
} derive(Debug, Eq)

///|
/// Construct a shared budget from validated parser resource limits.
pub fn DecodeBudget::new(
  limits : @model.ResourceLimits,
) -> DecodeBudget raise @model.MimeError {
  limits.validate()
  {
    per_leaf_limit: limits.max_decoded_leaf_bytes,
    total_limit: limits.max_total_decoded_bytes,
    consumed: 0,
  }
}

///|
/// Number of decoded bytes still available across all subsequent calls.
pub fn DecodeBudget::remaining(self : DecodeBudget) -> Int {
  self.total_limit - self.consumed
}

///|
/// Decode one leaf and atomically charge its output to this shared budget.
///
/// A failed decode does not consume budget. The effective bound is the lesser
/// of the configured per-leaf allowance and total remaining allowance.
pub fn DecodeBudget::decode_entity(
  self : DecodeBudget,
  message : @model.InternetMessage,
  entity : @model.MimeEntity,
  mode : @model.ParseMode,
) -> TransferDecodeResult raise @model.MimeError {
  if entity.kind != @model.Leaf {
    raise @model.InvalidArgument("decode budget accepts leaf entities only")
  }
  let remaining = self.remaining()
  if remaining <= 0 {
    raise @model.DecodedOutputTooLarge(self.consumed + 1, self.total_limit)
  }
  let effective_limit = if remaining < self.per_leaf_limit {
    remaining
  } else {
    self.per_leaf_limit
  }
  let result = decode_entity_body(
    message,
    entity,
    mode,
    max_output=effective_limit,
  )
  self.consumed = self.consumed + result.bytes.length()
  result
}
