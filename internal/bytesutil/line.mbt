///|
/// Line ending observed in the source representation.
#derive(Debug, Eq)
pub(all) enum LineEnding {
  CrLf
  Lf
  Cr
  EndOfInput
}

///|
/// One physical line with content excluding and range including its ending.
#derive(Debug, Eq)
pub(all) struct PhysicalLine {
  content_start : Int32
  content_end : Int32
  full_end : Int32
  ending : LineEnding
}

///|
/// Length of the physical line content in bytes.
pub fn PhysicalLine::content_length(self : PhysicalLine) -> Int32 {
  self.content_end - self.content_start
}

///|
/// Whether the line contains no bytes before its ending.
pub fn PhysicalLine::is_empty(self : PhysicalLine) -> Bool {
  self.content_start == self.content_end
}

///|
/// Read one physical line bounded by `end`.
pub fn next_line(input : Bytes, start : Int32, end : Int32) -> PhysicalLine? {
  if start < 0 || start >= end || end > input.length() {
    return None
  }
  let mut cursor = start
  while cursor < end {
    match input[cursor] {
      b'\r' => {
        if cursor + 1 < end && input[cursor + 1] == b'\n' {
          return Some({
            content_start: start,
            content_end: cursor,
            full_end: cursor + 2,
            ending: CrLf,
          })
        }
        return Some({
          content_start: start,
          content_end: cursor,
          full_end: cursor + 1,
          ending: Cr,
        })
      }
      b'\n' =>
        return Some({
          content_start: start,
          content_end: cursor,
          full_end: cursor + 1,
          ending: Lf,
        })
      _ => cursor = cursor + 1
    }
  }
  Some({
    content_start: start,
    content_end: end,
    full_end: end,
    ending: EndOfInput,
  })
}

///|
/// Return the start of a CRLF, LF, or CR ending directly before `offset`.
pub fn strip_preceding_line_break(
  input : Bytes,
  start : Int32,
  offset : Int32,
) -> Int32 {
  if offset <= start {
    return offset
  }
  if input[offset - 1] == b'\n' {
    if offset - 2 >= start && input[offset - 2] == b'\r' {
      offset - 2
    } else {
      offset - 1
    }
  } else if input[offset - 1] == b'\r' {
    offset - 1
  } else {
    offset
  }
}

///|
pub extend LineEnding with @debug.Debug::{to_repr}

///|
pub extend LineEnding with Eq::{not_equal, equal}

///|
pub extend PhysicalLine with @debug.Debug::{to_repr}

///|
pub extend PhysicalLine with Eq::{not_equal, equal}
