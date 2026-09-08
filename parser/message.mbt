///|
priv struct ParseState {
  mut entities : Int
  mut leaves : Int
  mut multiparts : Int
  mut embedded : Int
  mut maximum_depth : Int
  diagnostics : Array[@model.ParseDiagnostic]
}

///|
/// Parse an Internet Message into a byte-range-preserving MIME entity tree.
pub fn parse_message(
  input : Bytes,
  mode? : @model.ParseMode = @model.Strict,
  limits? : @model.ResourceLimits = @model.ResourceLimits::secure_defaults(),
) -> @model.InternetMessage raise @model.MimeError {
  limits.validate()
  if input.length() > limits.max_input_bytes {
    raise @model.InputTooLarge(input.length(), limits.max_input_bytes)
  }
  let state : ParseState = {
    entities: 0,
    leaves: 0,
    multiparts: 0,
    embedded: 0,
    maximum_depth: 0,
    diagnostics: [],
  }
  let root = parse_entity(input, 0, input.length(), 0, [], mode, limits, state)
  {
    raw: input,
    root,
    diagnostics: state.diagnostics,
    stats: {
      entities: state.entities,
      leaf_entities: state.leaves,
      multipart_entities: state.multiparts,
      embedded_messages: state.embedded,
      maximum_depth: state.maximum_depth,
      raw_bytes: input.length(),
    },
  }
}

///|
fn parse_entity(
  input : Bytes,
  start : Int,
  end : Int,
  depth : Int,
  path : Array[Int],
  mode : @model.ParseMode,
  limits : @model.ResourceLimits,
  state : ParseState,
) -> @model.MimeEntity raise @model.MimeError {
  if depth > limits.max_depth {
    raise @model.RecursionLimitExceeded(depth, limits.max_depth)
  }
  state.entities = state.entities + 1
  if state.entities > limits.max_entities {
    raise @model.EntityCountExceeded(state.entities, limits.max_entities)
  }
  if depth > state.maximum_depth {
    state.maximum_depth = depth
  }
  let header_result = @header.parse_header_block(
    input,
    start,
    end,
    mode,
    limits,
    entity_path=path,
  )
  append_diagnostics(state, header_result.diagnostics, limits)
  let metadata = @entity.interpret_headers(
    header_result.block,
    mode,
    limits,
    path=path,
  )
  append_diagnostics(state, metadata.diagnostics, limits)
  let body_start = header_result.block.body_start
  let body_range = @model.ByteRange::trusted(body_start, end)
  if metadata.media_type.is_multipart() {
    state.multiparts = state.multiparts + 1
    parse_multipart(
      input,
      start,
      end,
      body_start,
      depth,
      path,
      header_result.block,
      metadata,
      mode,
      limits,
      state,
    )
  } else if metadata.media_type.is_message_rfc822() {
    state.embedded = state.embedded + 1
    let children : Array[@model.MimeEntity] = []
    if body_start < end {
      match metadata.transfer_encoding {
        @model.SevenBit | @model.EightBit | @model.Binary => {
          let child_path = path.copy()
          child_path.push(0)
          children.push(
            parse_entity(input, body_start, end, depth + 1, child_path, mode, limits, state),
          )
        }
        encoding => {
          if mode == @model.Strict {
            raise @model.UnsupportedTransferEncoding(
              "cannot structurally parse encoded message/rfc822 body using " + encoding.to_string(),
            )
          }
        }
      }
    }
    {
      path,
      depth,
      headers: header_result.block,
      media_type: metadata.media_type,
      disposition: metadata.disposition,
      transfer_encoding: metadata.transfer_encoding,
      kind: @model.EmbeddedMessage,
      entity_range: @model.ByteRange::trusted(start, end),
      body_range,
      preamble_range: None,
      epilogue_range: None,
      children,
    }
  } else {
    let body_length = end - body_start
    if body_length > limits.max_leaf_body_bytes {
      raise @model.LeafBodyTooLarge(body_length, limits.max_leaf_body_bytes)
    }
    state.leaves = state.leaves + 1
    {
      path,
      depth,
      headers: header_result.block,
      media_type: metadata.media_type,
      disposition: metadata.disposition,
      transfer_encoding: metadata.transfer_encoding,
      kind: @model.Leaf,
      entity_range: @model.ByteRange::trusted(start, end),
      body_range,
      preamble_range: None,
      epilogue_range: None,
      children: [],
    }
  }
}

///|
fn parse_multipart(
  input : Bytes,
  entity_start : Int,
  entity_end : Int,
  body_start : Int,
  depth : Int,
  path : Array[Int],
  headers : @model.HeaderBlock,
  metadata : @entity.EntityMetadata,
  mode : @model.ParseMode,
  limits : @model.ResourceLimits,
  state : ParseState,
) -> @model.MimeEntity raise @model.MimeError {
  let boundary = metadata.media_type.parameter("boundary").unwrap()
  let scan = scan_boundaries(input, body_start, entity_end, boundary)
  if scan.delimiters.is_empty() || scan.delimiters[0].closing {
    raise @model.MissingBoundary("no opening delimiter for boundary " + boundary)
  }
  if !scan.closed {
    if mode == @model.Strict {
      raise @model.MissingClosingBoundary(boundary)
    }
    add_diagnostic(
      state,
      @model.MissingClosingBoundaryAccepted,
      "accepted multipart body without closing boundary " + boundary,
      @model.ByteRange::trusted(scan.delimiters[scan.delimiters.length() - 1].line_start, entity_end),
      path,
      limits,
    )
  }
  let children : Array[@model.MimeEntity] = []
  let mut closing : BoundaryDelimiter? = None
  let mut child_index = 0
  for index in 0..<scan.delimiters.length() {
    let delimiter = scan.delimiters[index]
    if delimiter.closing {
      closing = Some(delimiter)
      break
    }
    let child_start = delimiter.full_end
    let next_start = if index + 1 < scan.delimiters.length() {
      scan.delimiters[index + 1].line_start
    } else {
      entity_end
    }
    let child_end = @bytesutil.strip_preceding_line_break(input, child_start, next_start)
    if child_start >= child_end {
      raise @model.MalformedHeader(child_start, "multipart contains an empty MIME part")
    }
    let child_path = path.copy()
    child_path.push(child_index)
    children.push(
      parse_entity(input, child_start, child_end, depth + 1, child_path, mode, limits, state),
    )
    child_index = child_index + 1
  }
  let first = scan.delimiters[0]
  let preamble = @model.ByteRange::trusted(body_start, first.line_start)
  let epilogue = match closing {
    Some(value) => @model.ByteRange::trusted(value.full_end, entity_end)
    None => @model.ByteRange::trusted(entity_end, entity_end)
  }
  {
    path,
    depth,
    headers,
    media_type: metadata.media_type,
    disposition: metadata.disposition,
    transfer_encoding: metadata.transfer_encoding,
    kind: @model.Multipart,
    entity_range: @model.ByteRange::trusted(entity_start, entity_end),
    body_range: @model.ByteRange::trusted(body_start, entity_end),
    preamble_range: Some(preamble),
    epilogue_range: Some(epilogue),
    children,
  }
}

///|
fn append_diagnostics(
  state : ParseState,
  incoming : Array[@model.ParseDiagnostic],
  limits : @model.ResourceLimits,
) -> Unit {
  for diagnostic in incoming {
    if state.diagnostics.length() >= limits.max_diagnostics {
      return
    }
    state.diagnostics.push(diagnostic)
  }
}

///|
fn add_diagnostic(
  state : ParseState,
  code : @model.DiagnosticCode,
  message : String,
  range : @model.ByteRange,
  path : Array[Int],
  limits : @model.ResourceLimits,
) -> Unit {
  if state.diagnostics.length() < limits.max_diagnostics {
    state.diagnostics.push({
      level: @model.Warning,
      code,
      message,
      range,
      entity_path: path.copy(),
    })
  }
}
