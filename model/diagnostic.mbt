///|
/// Parser behavior selected for non-standard but recognizable input.
#derive(Debug, Eq)
pub(all) enum ParseMode {
  Strict
  Compatible
}

///|
/// Severity of a non-fatal parse observation.
#derive(Debug, Eq)
pub(all) enum DiagnosticLevel {
  Warning
  Info
}

///|
/// Machine-stable diagnostic codes returned in compatible mode.
#derive(Debug, Eq)
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
}

///|
/// Structured observation about accepted non-standard input.
#derive(Debug, Eq)
pub(all) struct ParseDiagnostic {
  level : DiagnosticLevel
  code : DiagnosticCode
  message : String
  range : ByteRange
  entity_path : Array[Int32]
}

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

///|
pub extend ParseMode with @debug.Debug::{to_repr}

///|
pub extend ParseMode with Eq::{not_equal, equal}

///|
pub extend DiagnosticLevel with @debug.Debug::{to_repr}

///|
pub extend DiagnosticLevel with Eq::{not_equal, equal}

///|
pub extend DiagnosticCode with @debug.Debug::{to_repr}

///|
pub extend DiagnosticCode with Eq::{not_equal, equal}

///|
pub extend ParseDiagnostic with @debug.Debug::{to_repr}

///|
pub extend ParseDiagnostic with Eq::{not_equal, equal}
