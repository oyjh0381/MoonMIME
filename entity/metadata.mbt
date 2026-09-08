///|
/// MIME semantics derived from one already parsed header block.
pub(all) struct EntityMetadata {
  media_type : @model.MediaType
  disposition : @model.ContentDisposition?
  transfer_encoding : @model.TransferEncoding
  diagnostics : Array[@model.ParseDiagnostic]
} derive(Debug, Eq)

///|
/// Interpret the singleton MIME fields of one entity.
pub fn interpret_headers(
  headers : @model.HeaderBlock,
  mode : @model.ParseMode,
  limits : @model.ResourceLimits,
  path? : Array[Int] = [],
) -> EntityMetadata raise @model.MimeError {
  let diagnostics : Array[@model.ParseDiagnostic] = []
  observe_duplicates(headers, "content-type", mode, diagnostics, limits, path)
  observe_duplicates(headers, "content-disposition", mode, diagnostics, limits, path)
  observe_duplicates(headers, "content-transfer-encoding", mode, diagnostics, limits, path)
  let media_type = read_media_type(headers, mode, limits, diagnostics, path)
  validate_boundary(media_type, limits)
  let disposition = read_disposition(headers, mode, limits, diagnostics, path)
  let transfer_encoding = read_transfer_encoding(headers, mode, limits, diagnostics, path)
  { media_type, disposition, transfer_encoding, diagnostics }
}

///|
fn read_media_type(
  headers : @model.HeaderBlock,
  mode : @model.ParseMode,
  limits : @model.ResourceLimits,
  diagnostics : Array[@model.ParseDiagnostic],
  path : Array[Int],
) -> @model.MediaType raise @model.MimeError {
  match headers.first("content-type") {
    None => @model.MediaType::text_plain()
    Some(field) => {
      let parsed : @model.MediaType? = try {
        @media.parse_media_type(field.value, mode, limits.max_parameter_count) |> Some
      } catch {
        error => {
          if mode == @model.Strict { raise error }
          add_diagnostic(diagnostics, @model.InvalidParameterPreserved, "ignored invalid Content-Type and applied text/plain", field.value_range, path, limits)
          None
        }
      }
      match parsed {
        None => @model.MediaType::text_plain()
        Some(value) => {
          let resolved : @model.MediaType? = try {
            @media.resolve_media_type(value, mode) |> Some
          } catch {
            @model.UnsupportedCharset(charset) => {
              if mode == @model.Strict { raise @model.UnsupportedCharset(charset) }
              add_diagnostic(diagnostics, @model.UnsupportedCharsetPreserved, "preserved Content-Type parameter with unsupported charset " + charset, field.value_range, path, limits)
              None
            }
            error => {
              if mode == @model.Strict { raise error }
              add_diagnostic(diagnostics, @model.InvalidParameterPreserved, "preserved unresolved Content-Type parameters", field.value_range, path, limits)
              None
            }
          }
          match resolved { Some(result) => result; None => value }
        }
      }
    }
  }
}

///|
fn read_disposition(
  headers : @model.HeaderBlock,
  mode : @model.ParseMode,
  limits : @model.ResourceLimits,
  diagnostics : Array[@model.ParseDiagnostic],
  path : Array[Int],
) -> @model.ContentDisposition? raise @model.MimeError {
  match headers.first("content-disposition") {
    None => None
    Some(field) => {
      let parsed : @model.ContentDisposition? = try {
        @media.parse_content_disposition(field.value, mode, limits.max_parameter_count) |> Some
      } catch {
        error => {
          if mode == @model.Strict { raise error }
          add_diagnostic(diagnostics, @model.InvalidParameterPreserved, "ignored invalid Content-Disposition", field.value_range, path, limits)
          None
        }
      }
      match parsed {
        None => None
        Some(value) => {
          let resolved : @model.ContentDisposition? = try {
            @media.resolve_disposition(value, mode) |> Some
          } catch {
            error => {
              if mode == @model.Strict { raise error }
              add_diagnostic(diagnostics, @model.InvalidParameterPreserved, "preserved unresolved Content-Disposition parameters", field.value_range, path, limits)
              None
            }
          }
          match resolved { Some(result) => Some(result); None => Some(value) }
        }
      }
    }
  }
}

///|
fn read_transfer_encoding(
  headers : @model.HeaderBlock,
  mode : @model.ParseMode,
  limits : @model.ResourceLimits,
  diagnostics : Array[@model.ParseDiagnostic],
  path : Array[Int],
) -> @model.TransferEncoding raise @model.MimeError {
  match headers.first("content-transfer-encoding") {
    None => @model.SevenBit
    Some(field) => {
      let encoding = @media.parse_transfer_encoding(field.value)
      match encoding {
        @model.Extension(value) => {
          if mode == @model.Strict { raise @model.UnsupportedTransferEncoding(value) }
          add_diagnostic(diagnostics, @model.UnknownTransferEncodingPreserved, "preserved unknown Content-Transfer-Encoding " + value, field.value_range, path, limits)
          encoding
        }
        _ => encoding
      }
    }
  }
}

///|
fn validate_boundary(media_type : @model.MediaType, limits : @model.ResourceLimits) -> Unit raise @model.MimeError {
  if !media_type.is_multipart() { return }
  let boundary = match media_type.parameter("boundary") {
    Some(value) => value
    None => raise @model.MissingBoundary(media_type.essence())
  }
  let bytes = @utf8.encode(boundary)
  if bytes.is_empty() { raise @model.InvalidBoundary("multipart boundary is empty") }
  if bytes.length() > limits.max_boundary_bytes {
    raise @model.InvalidBoundary("multipart boundary exceeds configured \{limits.max_boundary_bytes}-byte limit")
  }
  if bytes[bytes.length() - 1] == b' ' { raise @model.InvalidBoundary("multipart boundary must not end in a space") }
  for byte in bytes {
    if byte < b' ' || byte >= b'\x7f' { raise @model.InvalidBoundary("multipart boundary must contain printable ASCII") }
  }
}

///|
fn observe_duplicates(
  headers : @model.HeaderBlock,
  name : StringView,
  mode : @model.ParseMode,
  diagnostics : Array[@model.ParseDiagnostic],
  limits : @model.ResourceLimits,
  path : Array[Int],
) -> Unit raise @model.MimeError {
  let matches = headers.all(name)
  if matches.length() <= 1 { return }
  if mode == @model.Strict {
    raise @model.MalformedHeader(matches[1].field_range.start, "duplicate singleton MIME field " + name.to_owned())
  }
  add_diagnostic(diagnostics, @model.DuplicateSingletonHeader, "used first occurrence of duplicate singleton MIME field " + name.to_owned(), matches[1].field_range, path, limits)
}

///|
fn add_diagnostic(
  diagnostics : Array[@model.ParseDiagnostic],
  code : @model.DiagnosticCode,
  message : String,
  range : @model.ByteRange,
  path : Array[Int],
  limits : @model.ResourceLimits,
) -> Unit {
  if diagnostics.length() < limits.max_diagnostics {
    diagnostics.push({ level: @model.Warning, code, message, range, entity_path: path.copy() })
  }
}
