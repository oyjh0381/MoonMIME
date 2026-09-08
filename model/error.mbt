///|
/// Stable error categories exposed by MoonMIME.
pub(all) suberror MimeError {
  InvalidArgument(String)
  InputTooLarge(Int, Int)
  HeaderSectionTooLarge(Int, Int)
  HeaderLineTooLong(Int, Int)
  HeaderCountExceeded(Int, Int)
  MalformedHeader(Int, String)
  MissingHeaderTerminator(Int)
  InvalidMediaType(String)
  InvalidDisposition(String)
  InvalidBoundary(String)
  MissingBoundary(String)
  MissingClosingBoundary(String)
  RecursionLimitExceeded(Int, Int)
  EntityCountExceeded(Int, Int)
  LeafBodyTooLarge(Int, Int)
  DecodedOutputTooLarge(Int, Int)
  InvalidBase64(Int, String)
  InvalidQuotedPrintable(Int, String)
  UnsupportedTransferEncoding(String)
  UnsupportedCharset(String)
  InvalidEncodedWord(String)
  InvalidByteRange(Int, Int, Int)
  IoFailure(String)
} derive(Debug, Eq)

///|
/// Stable machine-readable category for automation and CLI clients.
pub fn MimeError::code(self : MimeError) -> String {
  match self {
    InvalidArgument(_) => "MOONMIME_ARGUMENT"
    InputTooLarge(_, _) => "MOONMIME_INPUT_LIMIT"
    HeaderSectionTooLarge(_, _) => "MOONMIME_HEADER_SIZE_LIMIT"
    HeaderLineTooLong(_, _) => "MOONMIME_HEADER_LINE_LIMIT"
    HeaderCountExceeded(_, _) => "MOONMIME_HEADER_COUNT_LIMIT"
    MalformedHeader(_, _) => "MOONMIME_MALFORMED_HEADER"
    MissingHeaderTerminator(_) => "MOONMIME_HEADER_TERMINATOR"
    InvalidMediaType(_) => "MOONMIME_MEDIA_TYPE"
    InvalidDisposition(_) => "MOONMIME_DISPOSITION"
    InvalidBoundary(_) => "MOONMIME_BOUNDARY"
    MissingBoundary(_) => "MOONMIME_BOUNDARY_MISSING"
    MissingClosingBoundary(_) => "MOONMIME_BOUNDARY_UNCLOSED"
    RecursionLimitExceeded(_, _) => "MOONMIME_RECURSION_LIMIT"
    EntityCountExceeded(_, _) => "MOONMIME_ENTITY_LIMIT"
    LeafBodyTooLarge(_, _) => "MOONMIME_LEAF_LIMIT"
    DecodedOutputTooLarge(_, _) => "MOONMIME_DECODED_LIMIT"
    InvalidBase64(_, _) => "MOONMIME_BASE64"
    InvalidQuotedPrintable(_, _) => "MOONMIME_QUOTED_PRINTABLE"
    UnsupportedTransferEncoding(_) => "MOONMIME_TRANSFER_UNSUPPORTED"
    UnsupportedCharset(_) => "MOONMIME_CHARSET_UNSUPPORTED"
    InvalidEncodedWord(_) => "MOONMIME_ENCODED_WORD"
    InvalidByteRange(_, _, _) => "MOONMIME_RANGE"
    IoFailure(_) => "MOONMIME_IO"
  }
}

///|
/// Human-readable detail for a structured failure.
pub fn MimeError::message(self : MimeError) -> String {
  match self {
    InvalidArgument(message)
    | InvalidMediaType(message)
    | InvalidDisposition(message)
    | InvalidBoundary(message)
    | MissingBoundary(message)
    | MissingClosingBoundary(message)
    | UnsupportedTransferEncoding(message)
    | UnsupportedCharset(message)
    | InvalidEncodedWord(message)
    | IoFailure(message) => message
    InputTooLarge(actual, limit) =>
      "input contains \{actual} bytes; configured limit is \{limit}"
    HeaderSectionTooLarge(actual, limit) =>
      "header section contains \{actual} bytes; configured limit is \{limit}"
    HeaderLineTooLong(actual, limit) =>
      "header line contains \{actual} bytes; configured limit is \{limit}"
    HeaderCountExceeded(actual, limit) =>
      "header section contains \{actual} fields; configured limit is \{limit}"
    MalformedHeader(offset, message) =>
      "malformed header at byte \{offset}: " + message
    MissingHeaderTerminator(offset) =>
      "header section starting at byte \{offset} has no empty-line terminator"
    RecursionLimitExceeded(actual, limit) =>
      "MIME nesting depth \{actual} exceeds configured limit \{limit}"
    EntityCountExceeded(actual, limit) =>
      "MIME entity count \{actual} exceeds configured limit \{limit}"
    LeafBodyTooLarge(actual, limit) =>
      "leaf body contains \{actual} bytes; configured limit is \{limit}"
    DecodedOutputTooLarge(actual, limit) =>
      "decoded output contains \{actual} bytes; configured limit is \{limit}"
    InvalidBase64(offset, message) =>
      "invalid Base64 at byte \{offset}: " + message
    InvalidQuotedPrintable(offset, message) =>
      "invalid Quoted-Printable at byte \{offset}: " + message
    InvalidByteRange(start, end, length) =>
      "invalid byte range [\{start}, \{end}) for \{length}-byte input"
  }
}

///|
/// Process exit status used by the reference command line program.
pub fn MimeError::exit_code(self : MimeError) -> Int {
  match self {
    InvalidArgument(_) => 2
    IoFailure(_) => 3
    InputTooLarge(_, _)
    | HeaderSectionTooLarge(_, _)
    | HeaderLineTooLong(_, _)
    | HeaderCountExceeded(_, _)
    | RecursionLimitExceeded(_, _)
    | EntityCountExceeded(_, _)
    | LeafBodyTooLarge(_, _)
    | DecodedOutputTooLarge(_, _) => 5
    _ => 4
  }
}

