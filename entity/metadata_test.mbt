///|
fn parsed_headers(text : String) -> @model.HeaderBlock raise {
  let raw = @utf8.encode(text)
  @header.parse_header_block(
    raw,
    0,
    raw.length(),
    @model.Strict,
    @model.ResourceLimits::secure_defaults(),
  ).block
}

///|
test "metadata applies MIME defaults" {
  let result = interpret_headers(
    parsed_headers("Subject: hello\r\n\r\nbody"),
    @model.Strict,
    @model.ResourceLimits::secure_defaults(),
  )
  assert_eq(result.media_type.essence(), "text/plain")
  assert_eq(result.transfer_encoding, @model.SevenBit)
  assert_eq(result.disposition, None)
}

///|
test "metadata resolves extended filenames" {
  let headers = parsed_headers(
    "Content-Disposition: attachment; filename*=UTF-8''%E6%B5%8B%E8%AF%95.txt\r\n\r\n",
  )
  let result = interpret_headers(
    headers,
    @model.Strict,
    @model.ResourceLimits::secure_defaults(),
  )
  assert_eq(
    result.disposition.unwrap().parameter("filename"),
    Some("测试.txt"),
  )
}

///|
test "metadata normalizes transfer encoding" {
  let headers = parsed_headers("Content-Transfer-Encoding: BASE64\r\n\r\n")
  let result = interpret_headers(
    headers,
    @model.Strict,
    @model.ResourceLimits::secure_defaults(),
  )
  assert_eq(result.transfer_encoding, @model.Base64)
}

///|
test "multipart requires boundary" {
  let headers = parsed_headers("Content-Type: multipart/mixed\r\n\r\n")
  let mut failed = false
  ignore(
    interpret_headers(
      headers,
      @model.Strict,
      @model.ResourceLimits::secure_defaults(),
    ),
  ) catch {
    @model.MissingBoundary(_) => failed = true
    _ => ()
  }
  assert_true(failed)
}

///|
test "boundary length is bounded" {
  let headers = parsed_headers(
    "Content-Type: multipart/mixed; boundary=abcdefghijklmnop\r\n\r\n",
  )
  let limits = {
    ..@model.ResourceLimits::secure_defaults(),
    max_boundary_bytes: 8,
  }
  let mut failed = false
  ignore(interpret_headers(headers, @model.Strict, limits)) catch {
    @model.InvalidBoundary(_) => failed = true
    _ => ()
  }
  assert_true(failed)
}

///|
test "strict mode rejects duplicate singleton fields" {
  let headers = parsed_headers(
    "Content-Type: text/plain\r\nContent-Type: text/html\r\n\r\n",
  )
  let mut failed = false
  ignore(
    interpret_headers(
      headers,
      @model.Strict,
      @model.ResourceLimits::secure_defaults(),
    ),
  ) catch {
    @model.MalformedHeader(_, _) => failed = true
    _ => ()
  }
  assert_true(failed)
}

///|
test "compatible mode reports duplicate singleton fields" {
  let headers = parsed_headers(
    "Content-Type: text/plain\r\nContent-Type: text/html\r\n\r\n",
  )
  let result = interpret_headers(
    headers,
    @model.Compatible,
    @model.ResourceLimits::secure_defaults(),
  )
  assert_eq(result.media_type.essence(), "text/plain")
  assert_eq(result.diagnostics.length(), 1)
  assert_eq(result.diagnostics[0].code, @model.DuplicateSingletonHeader)
}

///|
test "strict mode rejects unknown transfer encoding" {
  let headers = parsed_headers("Content-Transfer-Encoding: x-custom\r\n\r\n")
  let mut failed = false
  ignore(
    interpret_headers(
      headers,
      @model.Strict,
      @model.ResourceLimits::secure_defaults(),
    ),
  ) catch {
    @model.UnsupportedTransferEncoding("x-custom") => failed = true
    _ => ()
  }
  assert_true(failed)
}

///|
test "compatible mode preserves unknown transfer encoding" {
  let headers = parsed_headers("Content-Transfer-Encoding: x-custom\r\n\r\n")
  let result = interpret_headers(
    headers,
    @model.Compatible,
    @model.ResourceLimits::secure_defaults(),
  )
  assert_eq(result.transfer_encoding, @model.Extension("x-custom"))
  assert_eq(result.diagnostics[0].code, @model.UnknownTransferEncodingPreserved)
}

///|
test "compatible mode defaults malformed content type" {
  let headers = parsed_headers("Content-Type: not-a-type\r\n\r\n")
  let result = interpret_headers(
    headers,
    @model.Compatible,
    @model.ResourceLimits::secure_defaults(),
  )
  assert_eq(result.media_type.essence(), "text/plain")
  assert_eq(result.diagnostics[0].code, @model.InvalidParameterPreserved)
}
