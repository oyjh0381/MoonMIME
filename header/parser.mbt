///|
/// Header parser output with non-fatal compatibility observations.
pub(all) struct HeaderParseResult {
  block : @model.HeaderBlock
  diagnostics : Array[@model.ParseDiagnostic]
} derive(Debug, Eq)

///|
priv struct PendingHeader {
  name : String
  lower_name : String
  parts : Array[String]
  start : Int
  value_start : Int
  mut end : Int
  mut lines : Int
}

///|
/// Parse one RFC 5322-style header section inside a bounded entity range.
pub fn parse_header_block(
  input : Bytes,
  start : Int,
  end : Int,
  mode : @model.ParseMode,
  limits : @model.ResourceLimits,
  entity_path? : Array[Int] = [],
) -> HeaderParseResult raise @model.MimeError {
  if start < 0 || end < start || end > input.length() {
    raise @model.InvalidByteRange(start, end, input.length())
  }
  let fields : Array[@model.HeaderField] = []
  let diagnostics : Array[@model.ParseDiagnostic] = []
  let mut current : PendingHeader? = None
  let mut cursor = start
  let mut body_start : Int? = None
  while cursor < end {
    let line = @bytesutil.next_line(input, cursor, end).unwrap()
    let header_bytes = line.full_end - start
    if header_bytes > limits.max_header_bytes {
      raise @model.HeaderSectionTooLarge(header_bytes, limits.max_header_bytes)
    }
    if line.content_length() > limits.max_header_line_bytes {
      raise @model.HeaderLineTooLong(
        line.content_length(),
        limits.max_header_line_bytes,
      )
    }
    observe_line_ending(diagnostics, line, mode, limits, entity_path)
    if line.is_empty() {
      finish_pending(fields, current)
      current = None
      body_start = Some(line.full_end)
      cursor = line.full_end
      break
    }
    if @bytesutil.is_wsp(input[line.content_start]) {
      match current {
        Some(pending) => {
          let (left, right) = @bytesutil.trim_wsp(
            input,
            line.content_start,
            line.content_end,
          )
          pending.parts.push(decode_value(input, left, right))
          pending.end = line.full_end
          pending.lines = pending.lines + 1
        }
        None => {
          if mode == @model.Strict {
            raise @model.MalformedHeader(
              line.content_start,
              "continuation line has no preceding field",
            )
          }
          add_diagnostic(
            diagnostics,
            @model.ContinuationWithoutField,
            "ignored continuation line without a preceding header field",
            @model.ByteRange::trusted(line.content_start, line.full_end),
            entity_path,
            limits,
          )
        }
      }
      cursor = line.full_end
      continue
    }
    finish_pending(fields, current)
    current = None
    if fields.length() >= limits.max_header_count {
      raise @model.HeaderCountExceeded(
        fields.length() + 1,
        limits.max_header_count,
      )
    }
    let colon = find_colon(input, line.content_start, line.content_end)
    match colon {
      None => {
        if mode == @model.Strict {
          raise @model.MalformedHeader(
            line.content_start,
            "header field has no colon",
          )
        }
        add_diagnostic(
          diagnostics,
          @model.HeaderWithoutColon,
          "ignored header line without a colon",
          @model.ByteRange::trusted(line.content_start, line.full_end),
          entity_path,
          limits,
        )
      }
      Some(colon) => {
        let (name_start, name_end) = @bytesutil.trim_wsp(
          input,
          line.content_start,
          colon,
        )
        if name_start != line.content_start || name_end != colon {
          if mode == @model.Strict {
            raise @model.MalformedHeader(
              line.content_start,
              "whitespace before the field-name colon is forbidden",
            )
          }
          add_diagnostic(
            diagnostics,
            @model.HeaderWhitespaceBeforeColon,
            "trimmed whitespace before the field-name colon",
            @model.ByteRange::trusted(line.content_start, colon),
            entity_path,
            limits,
          )
        }
        if name_start == name_end {
          raise @model.MalformedHeader(
            line.content_start,
            "header field name is empty",
          )
        }
        validate_field_name(input, name_start, name_end)
        let name = @bytesutil.ascii_string(input, name_start, name_end)
        let (value_start, value_end) = @bytesutil.trim_wsp(
          input,
          colon + 1,
          line.content_end,
        )
        current = Some({
          name,
          lower_name: @bytesutil.lower_string(name),
          parts: [decode_value(input, value_start, value_end)],
          start: line.content_start,
          value_start: colon + 1,
          end: line.full_end,
          lines: 1,
        })
      }
    }
    cursor = line.full_end
  }
  if body_start is None {
    raise @model.MissingHeaderTerminator(start)
  }
  {
    block: {
      fields,
      range: @model.ByteRange::trusted(start, body_start.unwrap()),
      body_start: body_start.unwrap(),
    },
    diagnostics,
  }
}

///|
fn finish_pending(
  fields : Array[@model.HeaderField],
  pending : PendingHeader?,
) -> Unit {
  match pending {
    Some(value) =>
      fields.push({
        name: value.name,
        lower_name: value.lower_name,
        value: value.parts.join(" "),
        field_range: @model.ByteRange::trusted(value.start, value.end),
        value_range: @model.ByteRange::trusted(value.value_start, value.end),
        line_count: value.lines,
      })
    None => ()
  }
}

///|
fn find_colon(input : Bytes, start : Int, end : Int) -> Int? {
  for index in start..<end {
    if input[index] == b':' {
      return Some(index)
    }
  }
  None
}

///|
fn validate_field_name(
  input : Bytes,
  start : Int,
  end : Int,
) -> Unit raise @model.MimeError {
  for index in start..<end {
    if !@bytesutil.is_field_name(input[index]) {
      raise @model.MalformedHeader(
        index, "field name contains a non-printable or non-ASCII byte",
      )
    }
  }
}

///|
fn decode_value(input : Bytes, start : Int, end : Int) -> String {
  @utf8.decode(input[start:end]) catch {
    _ =>
      @bytesutil.latin1_string(Bytes::from_array(input[start:end].to_array()))
  }
}

///|
fn observe_line_ending(
  diagnostics : Array[@model.ParseDiagnostic],
  line : @bytesutil.PhysicalLine,
  mode : @model.ParseMode,
  limits : @model.ResourceLimits,
  path : Array[Int],
) -> Unit raise @model.MimeError {
  match line.ending {
    @bytesutil.CrLf => ()
    @bytesutil.Lf => {
      if mode == @model.Strict {
        raise @model.MalformedHeader(
          line.content_end,
          "bare line feed in strict mode",
        )
      }
      add_diagnostic(
        diagnostics,
        @model.BareLineFeed,
        "accepted bare LF line ending",
        @model.ByteRange::trusted(line.content_end, line.full_end),
        path,
        limits,
      )
    }
    @bytesutil.Cr => {
      if mode == @model.Strict {
        raise @model.MalformedHeader(
          line.content_end,
          "bare carriage return in strict mode",
        )
      }
      add_diagnostic(
        diagnostics,
        @model.BareCarriageReturn,
        "accepted bare CR line ending",
        @model.ByteRange::trusted(line.content_end, line.full_end),
        path,
        limits,
      )
    }
    @bytesutil.EndOfInput => ()
  }
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
    diagnostics.push({
      level: @model.Warning,
      code,
      message,
      range,
      entity_path: path.copy(),
    })
  }
}
