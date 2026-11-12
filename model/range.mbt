///|
/// Half-open byte range into an Internet Message's Raw Representation.
#derive(Debug, Eq)
pub(all) struct ByteRange {
  start : Int32
  end : Int32
}

///|
/// Construct a range after validating monotonic non-negative bounds.
pub fn ByteRange::new(start : Int32, end : Int32) -> ByteRange raise MimeError {
  if start < 0 || end < start {
    raise InvalidByteRange(start, end, end)
  }
  { start, end, }
}

///|
/// Construct a range known to have already been validated by the parser.
pub fn ByteRange::trusted(start : Int32, end : Int32) -> ByteRange {
  { start, end, }
}

///|
/// Number of bytes covered by the range.
pub fn ByteRange::length(self : ByteRange) -> Int32 {
  self.end - self.start
}

///|
/// Whether the range contains no bytes.
pub fn ByteRange::is_empty(self : ByteRange) -> Bool {
  self.start == self.end
}

///|
/// Whether an absolute byte offset lies within this half-open range.
pub fn ByteRange::contains(self : ByteRange, offset : Int32) -> Bool {
  offset >= self.start && offset < self.end
}

///|
/// Verify that the range can safely slice an input of `input_length` bytes.
pub fn ByteRange::validate(
  self : ByteRange,
  input_length : Int32,
) -> Unit raise MimeError {
  if self.start < 0 || self.end < self.start || self.end > input_length {
    raise InvalidByteRange(self.start, self.end, input_length)
  }
}

///|
pub extend ByteRange with @debug.Debug::{to_repr}

///|
pub extend ByteRange with Eq::{not_equal, equal}
