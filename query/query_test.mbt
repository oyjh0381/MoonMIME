///|
fn query_message(text : String) -> @model.InternetMessage raise {
  @parser.parse_message(@utf8.encode(text))
}

///|
test "entities returns depth first preorder" {
  let message = query_message(
    "Content-Type: multipart/mixed; boundary=x\r\n\r\n--x\r\n\r\na\r\n--x\r\nContent-Type: message/rfc822\r\n\r\n\r\nb\r\n--x--\r\n",
  )
  assert_eq(entities(message).map(item => item.path), [[], [0], [1], [1, 0]])
}

///|
test "find entity accepts root and nested paths" {
  let message = query_message(
    "Content-Type: multipart/mixed; boundary=x\r\n\r\n--x\r\n\r\na\r\n--x--\r\n",
  )
  assert_eq(find_entity(message, []).unwrap().kind, @model.Multipart)
  assert_eq(find_entity(message, [0]).unwrap().kind, @model.Leaf)
}

///|
test "find entity rejects invalid path" {
  let message = query_message("\r\nbody")
  assert_eq(find_entity(message, [0]), None)
  assert_eq(find_entity(message, [-1]), None)
}

///|
test "attachments include explicit attachment" {
  let message = query_message(
    "Content-Disposition: attachment; filename=report.txt\r\nContent-Type: text/plain\r\n\r\ndata",
  )
  let found = attachments(message)
  assert_eq(found.length(), 1)
  assert_true(found[0].explicit)
  assert_eq(found[0].filename, Some("report.txt"))
}

///|
test "attachments include inline named resource" {
  let message = query_message(
    "Content-Disposition: inline; filename=image.png\r\nContent-Type: image/png\r\n\r\ndata",
  )
  let found = attachments(message)
  assert_eq(found.length(), 1)
  assert_false(found[0].explicit)
}

///|
test "unnamed body is not an attachment" {
  let message = query_message("Content-Type: text/plain\r\n\r\ndata")
  assert_eq(attachments(message), [])
}

///|
test "subject decodes encoded words" {
  let message = query_message("Subject: =?UTF-8?B?5L2g5aW9?=\r\n\r\n")
  assert_eq(subject(message), Some("你好"))
}

///|
test "preferred text decodes Base64 UTF-8" {
  let message = query_message(
    "Content-Type: text/plain; charset=utf-8\r\nContent-Transfer-Encoding: base64\r\n\r\naGVsbG8=",
  )
  let selected = preferred_text(message).unwrap()
  assert_eq(selected.text, "hello")
  assert_eq(selected.charset, Some("utf-8"))
}

///|
test "preferred text chooses plain over html" {
  let message = query_message(
    "Content-Type: multipart/alternative; boundary=x\r\n\r\n--x\r\nContent-Type: text/html\r\n\r\n<b>html</b>\r\n--x\r\nContent-Type: text/plain\r\n\r\nplain\r\n--x--\r\n",
  )
  let selected = preferred_text(message).unwrap()
  assert_eq(selected.media_type, "text/plain")
  assert_eq(selected.text, "plain")
}

///|
test "preferred text ignores explicit text attachment" {
  let message = query_message(
    "Content-Type: multipart/mixed; boundary=x\r\n\r\n--x\r\nContent-Type: text/plain\r\nContent-Disposition: attachment; filename=a.txt\r\n\r\nsecret\r\n--x--\r\n",
  )
  assert_eq(preferred_text(message), None)
}

///|
test "preferred text supports Latin-1" {
  let input = Bytes::from_array(
    @utf8.encode(
      "Content-Type: text/plain; charset=iso-8859-1\r\nContent-Transfer-Encoding: quoted-printable\r\n\r\ncaf=E9",
    ).to_array(),
  )
  let message = @parser.parse_message(input)
  assert_eq(preferred_text(message).unwrap().text, "café")
}

///|
test "preferred text rejects unsupported charset" {
  let message = query_message(
    "Content-Type: text/plain; charset=koi8-r\r\n\r\nhello",
  )
  let mut failed = false
  ignore(preferred_text(message)) catch {
    @model.UnsupportedCharset("koi8-r") => failed = true
    _ => ()
  }
  assert_true(failed)
}
