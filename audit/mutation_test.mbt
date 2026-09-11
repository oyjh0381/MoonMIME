///|
test "10000 deterministic mutations never panic or hang" {
  let base = @utf8.encode(
    "From: sender@example.test\r\nSubject: mutation seed\r\nContent-Type: text/plain\r\n\r\nbody",
  )
  let alphabet = [
    b'\x00', b'\r', b'\n', b':', b';', b'"', b'=', b'-', b' ', b'A', b'/',
  ]
  let mut state = 0x13579bdf
  for _ in 0..<10000 {
    state = state * 1103515245 + 12345
    let bytes = base.to_array()
    let position = (state & 0x7fffffff) % bytes.length()
    state = state * 1103515245 + 12345
    bytes[position] = alphabet[(state & 0x7fffffff) % alphabet.length()]
    try {
      let message = @parser.parse_message(
        Bytes::from_array(bytes), mode=@model.Compatible,
      )
      ignore(audit_message(message))
    } catch {
      _ => ()
    }
  }
}
