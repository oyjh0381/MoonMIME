///|
test "RFC 2231 single extended filename decodes UTF-8" {
  let raw = parse_content_disposition(
    "attachment; filename*=UTF-8''%E2%82%AC%20rates.txt",
    @model.Strict,
    8,
  )
  let resolved = resolve_disposition(raw, @model.Strict)
  assert_eq(resolved.parameter("filename"), Some("€ rates.txt"))
}

///|
test "RFC 2231 continuation joins encoded and plain sections" {
  let raw = parse_content_disposition(
    "attachment; filename*0*=utf-8'en'%E6%8A%A5%E5%91%8A%20; filename*1=2026.pdf",
    @model.Strict,
    8,
  )
  let resolved = resolve_disposition(raw, @model.Strict)
  assert_eq(resolved.parameter("filename"), Some("报告 2026.pdf"))
}

///|
test "extended filename takes precedence over plain fallback" {
  let raw = parse_content_disposition(
    "attachment; filename=fallback.txt; filename*=utf-8''real.txt",
    @model.Strict,
    8,
  )
  let resolved = resolve_disposition(raw, @model.Strict)
  assert_eq(resolved.parameter("filename"), Some("real.txt"))
  assert_eq(resolved.parameters.length(), 1)
}

///|
test "last plain duplicate wins deterministically" {
  let raw = parse_content_disposition(
    "attachment; filename=first.txt; filename=last.txt",
    @model.Strict,
    8,
  )
  let resolved = resolve_disposition(raw, @model.Strict)
  assert_eq(resolved.parameter("filename"), Some("last.txt"))
}

///|
test "Latin-1 extended parameters map bytes losslessly" {
  let raw = parse_content_disposition(
    "attachment; filename*=iso-8859-1''caf%E9.txt",
    @model.Strict,
    8,
  )
  assert_eq(
    resolve_disposition(raw, @model.Strict).parameter("filename"),
    Some("café.txt"),
  )
}

///|
test "strict continuation rejects missing section zero" {
  assert_parameter_failure(
    "attachment; filename*1=tail.txt",
    "MOONMIME_PARAMETER",
  )
}

///|
test "strict continuation rejects gaps" {
  assert_parameter_failure(
    "attachment; filename*0=first; filename*2=third",
    "MOONMIME_PARAMETER",
  )
}

///|
test "compatible continuation keeps contiguous prefix" {
  let raw = parse_content_disposition(
    "attachment; filename*0=first; filename*2=third",
    @model.Strict,
    8,
  )
  assert_eq(
    resolve_disposition(raw, @model.Compatible).parameter("filename"),
    Some("first"),
  )
}

///|
test "extended parameter rejects invalid percent escape" {
  assert_parameter_failure(
    "attachment; filename*=utf-8''bad%XZname",
    "MOONMIME_PARAMETER",
  )
}

///|
test "extended parameter exposes unsupported charset" {
  assert_parameter_failure(
    "attachment; filename*=shift_jis''abc.txt",
    "MOONMIME_CHARSET_UNSUPPORTED",
  )
}

///|
fn assert_parameter_failure(source : String, expected : String) -> Unit raise {
  let raw = parse_content_disposition(source, @model.Strict, 16)
  let mut code : String? = None
  ignore(resolve_disposition(raw, @model.Strict)) catch {
    error => code = Some(error.code())
  }
  assert_eq(code, Some(expected))
}
