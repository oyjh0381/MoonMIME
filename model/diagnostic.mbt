///|
/// Parser behavior selected for non-standard but recognizable input.
pub(all) enum ParseMode {
  Strict
  Compatible
} derive(Debug, Eq)

///|
/// Severity of a non-fatal parse observation.
pub(all) enum DiagnosticLevel {
  Warning
  Info
} derive(Debug, Eq)

///|
/// Machine-stable diagnostic codes returned in compatible mode.
pub(all) enum DiagnosticCode {
  BareLineFeed
  BareCarriageReturn
  HeaderWhitespaceBeforeColon
  HeaderWithoutColon
  ContinuationWithoutField
  NonAsciiHeaderName
  DuplicateSingletonHeader
  InvalidEncodedWordPreserved
  UnknownTransferEncodingPreserved
  InvalidParameterPreserved
  MissingMultipartPreambleBreak
  TrailingBytesAfterBoundary
  MissingClosingBoundaryAccepted
  UnsupportedCharsetPreserved
} derive(Debug, Eq)

///|
/// Structured observation about accepted non-standard input.
pub(all) struct ParseDiagnostic {
  level : DiagnosticLevel
  code : DiagnosticCode
  message : String
  range : ByteRange
  entity_path : Array[Int]
} derive(Debug, Eq)

///|
/// Stable textual spelling used by JSON and CLI reports.
pub fn DiagnosticCode::to_code(self : DiagnosticCode) -> String {
  match self {
    BareLineFeed => "bare-line-feed"
    BareCarriageReturn => "bare-carriage-return"
    HeaderWhitespaceBeforeColon => "header-whitespace-before-colon"
    HeaderWithoutColon => "header-without-colon"
    ContinuationWithoutField => "continuation-without-field"
    NonAsciiHeaderName => "non-ascii-header-name"
    DuplicateSingletonHeader => "duplicate-singleton-header"
    InvalidEncodedWordPreserved => "invalid-encoded-word-preserved"
    UnknownTransferEncodingPreserved => "unknown-transfer-encoding-preserved"
    InvalidParameterPreserved => "invalid-parameter-preserved"
    MissingMultipartPreambleBreak => "missing-multipart-preamble-break"
    TrailingBytesAfterBoundary => "trailing-bytes-after-boundary"
    MissingClosingBoundaryAccepted => "missing-closing-boundary-accepted"
    UnsupportedCharsetPreserved => "unsupported-charset-preserved"
  }
}
