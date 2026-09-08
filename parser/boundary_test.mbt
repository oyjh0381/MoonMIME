///|
fn scan(text : String, boundary : String) -> BoundaryScan raise {
  let input = @utf8.encode(text)
  scan_boundaries(input, 0, input.length(), boundary)
}

///|
test "boundary scanner recognizes opening and closing lines" {
  let result = scan(
    "preamble\r\n--outer\r\npart\r\n--outer--\r\nepilogue", "outer",
  )
  assert_eq(result.delimiters.length(), 2)
  assert_false(result.delimiters[0].closing)
  assert_true(result.delimiters[1].closing)
  assert_true(result.closed)
}

///|
test "boundary scanner accepts transport padding" {
  let result = scan("--x \t\r\n--x--\t\r\n", "x")
  assert_eq(result.delimiters.length(), 2)
  assert_true(result.closed)
}

///|
test "boundary scanner ignores prefix matches" {
  let result = scan("--x-extra\r\n--x\r\n--x--\r\n", "x")
  assert_eq(result.delimiters.length(), 2)
}

///|
test "boundary scanner requires line anchoring" {
  let result = scan("text --x\r\n--x--\r\n", "x")
  assert_eq(result.delimiters.length(), 1)
  assert_true(result.delimiters[0].closing)
}

///|
test "boundary scanner does not search after closing delimiter" {
  let result = scan("--x\r\na\r\n--x--\r\n--x\r\nb", "x")
  assert_eq(result.delimiters.length(), 2)
}

///|
test "boundary scanner reports missing closing delimiter" {
  let result = scan("--x\r\na\r\n", "x")
  assert_eq(result.delimiters.length(), 1)
  assert_false(result.closed)
}

///|
test "boundary-like line with suffix is ordinary content" {
  let result = scan("--x?\r\n--x--oops\r\n", "x")
  assert_eq(result.delimiters.length(), 0)
}

///|
test "boundary scanner handles LF input without broad matching" {
  let result = scan("--b\npart\n--b--\n", "b")
  assert_eq(result.delimiters.length(), 2)
  assert_true(result.closed)
}

///|
test "boundary scanner handles final line without ending" {
  let result = scan("--b\r\npart\r\n--b--", "b")
  assert_eq(result.delimiters.length(), 2)
  assert_eq(result.delimiters[1].line_end, result.delimiters[1].full_end)
}

///|
test "boundary scanner validates source range" {
  let input = @utf8.encode("--x--")
  let mut failed = false
  ignore(scan_boundaries(input, -1, input.length(), "x")) catch {
    @model.InvalidByteRange(_, _, _) => failed = true
    _ => ()
  }
  assert_true(failed)
}
