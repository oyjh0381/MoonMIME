///|
test "ASCII token classification excludes MIME separators" {
  assert_true(@bytesutil.is_token(b'A'))
  assert_true(@bytesutil.is_token(b'-'))
  assert_false(@bytesutil.is_token(b'/'))
  assert_false(@bytesutil.is_token(b'='))
  assert_false(@bytesutil.is_token(b' '))
}

///|
test "ASCII lowercasing is locale independent" {
  assert_eq(@bytesutil.lower_string("Content-TYPE"), "content-type")
  assert_eq(@bytesutil.lower_string("x-ümlaut"), "x-ümlaut")
}

///|
test "bounded find does not cross the requested end" {
  let input = @utf8.encode("abc--needle--xyz")
  let needle = @utf8.encode("--needle")
  assert_eq(@bytesutil.find(input, needle, 0, input.length()), Some(3))
  assert_eq(@bytesutil.find(input, needle, 0, 8), None)
}

///|
test "range comparison supports ASCII case folding" {
  let input = @utf8.encode("Content-Type")
  assert_true(@bytesutil.equals_ascii(input, 0, 7, "Content"))
  assert_true(
    @bytesutil.equals_ascii_ci(input, 0, input.length(), "content-type"),
  )
  assert_false(
    @bytesutil.equals_ascii_ci(input, 0, input.length(), "content-length"),
  )
}

///|
test "physical line scanner distinguishes endings" {
  let input = @utf8.encode("one\r\ntwo\nthree\rfour")
  let one = @bytesutil.next_line(input, 0, input.length()).unwrap()
  assert_eq(one.ending, CrLf)
  assert_eq(one.content_length(), 3)
  let two = @bytesutil.next_line(input, one.full_end, input.length()).unwrap()
  assert_eq(two.ending, Lf)
  let three = @bytesutil.next_line(input, two.full_end, input.length()).unwrap()
  assert_eq(three.ending, Cr)
  let four = @bytesutil.next_line(input, three.full_end, input.length()).unwrap()
  assert_eq(four.ending, EndOfInput)
}

///|
test "trim helpers retain interior whitespace" {
  let input = @utf8.encode(" \t a b \r\n")
  let (left, right) = @bytesutil.trim_ascii_space(input, 0, input.length())
  assert_eq(@bytesutil.ascii_string(input, left, right), "a b")
}

///|
test "latin1 conversion preserves every byte value" {
  let bytes = Bytes::from_array([b'A', b'\xe9', b'Z'])
  assert_eq(@bytesutil.latin1_string(bytes), "AéZ")
}
