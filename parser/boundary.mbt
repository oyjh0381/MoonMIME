///|
/// One recognized MIME delimiter line.
pub(all) struct BoundaryDelimiter {
  line_start : Int32
  line_end : Int32
  full_end : Int32
  closing : Bool
} derive(Debug, Eq)

///|
/// Result of a line-anchored multipart boundary scan.
pub(all) struct BoundaryScan {
  delimiters : Array[BoundaryDelimiter]
  closed : Bool
} derive(Debug, Eq)

///|
/// Scan a bounded body for exact, line-anchored MIME delimiter lines.
///
/// Prefix matches such as `--boundary-extra` are deliberately ignored. Only
/// optional space/tab padding may follow the boundary token or closing `--`.
pub fn scan_boundaries(
  input : Bytes,
  start : Int32,
  end : Int32,
  boundary : String,
) -> BoundaryScan raise @model.MimeError {
  if start < 0 || end < start || end > input.length() {
    raise @model.InvalidByteRange(start, end, input.length())
  }
  let marker = @utf8.encode("--" + boundary)
  if marker.length() <= 2 {
    raise @model.InvalidBoundary("multipart boundary is empty")
  }
  let delimiters : Array[BoundaryDelimiter] = []
  let mut cursor = start
  let mut closed = false
  while cursor < end {
    let line = @bytesutil.next_line(input, cursor, end).unwrap()
    match recognize_delimiter(input, line, marker) {
      Some(delimiter) => {
        if closed {
          break
        }
        delimiters.push(delimiter)
        if delimiter.closing {
          closed = true
        }
      }
      None => ()
    }
    cursor = line.full_end
  }
  { delimiters, closed, }
}

///|
fn recognize_delimiter(
  input : Bytes,
  line : @bytesutil.PhysicalLine,
  marker : Bytes,
) -> BoundaryDelimiter? {
  if line.content_length() < marker.length() {
    return None
  }
  for index in 0..<marker.length() {
    if input[line.content_start + index] != marker[index] {
      return None
    }
  }
  let mut cursor = line.content_start + marker.length()
  let mut closing = false
  if cursor + 1 < line.content_end &&
    input[cursor] == b'-' &&
    input[cursor + 1] == b'-' {
    closing = true
    cursor = cursor + 2
  }
  while cursor < line.content_end && @bytesutil.is_wsp(input[cursor]) {
    cursor = cursor + 1
  }
  if cursor != line.content_end {
    return None
  }
  Some({
    line_start: line.content_start,
    line_end: line.content_end,
    full_end: line.full_end,
    closing,
  })
}

///|
pub extend BoundaryDelimiter with @debug.Debug::{to_repr}

///|
pub extend BoundaryDelimiter with Eq::{not_equal, equal}

///|
pub extend BoundaryScan with @debug.Debug::{to_repr}

///|
pub extend BoundaryScan with Eq::{not_equal, equal}
