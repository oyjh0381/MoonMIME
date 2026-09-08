///|
/// Half-open byte range into an Internet Message's Raw Representation.
pub(all) struct ByteRange {
  start : Int
  end : Int
} derive(Debug, Eq)

///|
/// Construct a range after validating monotonic non-negative bounds.
pub fn ByteRange::new(start : Int, end : Int) -> ByteRange raise MimeError {
  if start < 0 || end < start {
    raise InvalidByteRange(start, end, end)
  }
  { start, end, }
}

///|
/// Construct a range known to have already been validated by the parser.
pub fn ByteRange::trusted(start : Int, end : Int) -> ByteRange {
  { start, end, }
}

///|
/// Number of bytes covered by the range.
pub fn ByteRange::length(self : ByteRange) -> Int {
  self.end - self.start
}

///|
/// Whether the range contains no bytes.
pub fn ByteRange::is_empty(self : ByteRange) -> Bool {
  self.start == self.end
}

///|
/// Whether an absolute byte offset lies within this half-open range.
pub fn ByteRange::contains(self : ByteRange, offset : Int) -> Bool {
  offset >= self.start && offset < self.end
}

///|
/// Verify that the range can safely slice an input of `input_length` bytes.
pub fn ByteRange::validate(
  self : ByteRange,
  input_length : Int,
) -> Unit raise MimeError {
  if self.start < 0 || self.end < self.start || self.end > input_length {
    raise InvalidByteRange(self.start, self.end, input_length)
  }
}
