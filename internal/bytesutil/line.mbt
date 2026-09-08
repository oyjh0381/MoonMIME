///|
/// Line ending observed in the source representation.
pub(all) enum LineEnding {
  CrLf
  Lf
  Cr
  EndOfInput
} derive(Debug, Eq)

///|
/// One physical line with content excluding and range including its ending.
pub(all) struct PhysicalLine {
  content_start : Int
  content_end : Int
  full_end : Int
  ending : LineEnding
} derive(Debug, Eq)

///|
/// Length of the physical line content in bytes.
pub fn PhysicalLine::content_length(self : PhysicalLine) -> Int {
  self.content_end - self.content_start
}

///|
/// Whether the line contains no bytes before its ending.
pub fn PhysicalLine::is_empty(self : PhysicalLine) -> Bool {
  self.content_start == self.content_end
}

///|
/// Read one physical line bounded by `end`.
pub fn next_line(input : Bytes, start : Int, end : Int) -> PhysicalLine? {
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
pub fn strip_preceding_line_break(input : Bytes, start : Int, offset : Int) -> Int {
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

