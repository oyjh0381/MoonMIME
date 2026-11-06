///|
test "fingerprint distinguishes decoded bytes from encoded source without extraction" {
  let inventory = @evidence.observe(
    b"Content-Transfer-Encoding: base64\r\n\r\naGVsbG8=",
  )
  assert_true(inventory.complete)
  assert_eq(inventory.entities.length(), 1)
  assert_eq(inventory.entities[0].decoded_bytes, Some(5))
  assert_eq(
    inventory.entities[0].decoded_sha256,
    Some("2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824"),
  )
  assert_true(
    inventory.entities[0].encoded_sha256 !=
    inventory.entities[0].decoded_sha256.unwrap(),
  )
}

///|
test "opaque encoded embedded message never implies complete inspection" {
  let inventory = @evidence.observe(
    b"Content-Type: message/rfc822\r\nContent-Transfer-Encoding: base64\r\n\r\nU3ViamVjdDogYQ0KDQpoaQ==",
    mode=@model.Compatible,
  )
  assert_false(inventory.complete)
  assert_eq(inventory.entities[0].decode_status, "opaque")
  assert_eq(inventory.entities[0].decoded_sha256, None)
}

///|
test "shared decoding limit preserves wire evidence without inventing a payload" {
  let limits = {
    ..@model.ResourceLimits::secure_defaults(),
    max_decoded_leaf_bytes: 4,
    max_total_decoded_bytes: 4,
  }
  let inventory = @evidence.observe(
    b"Content-Transfer-Encoding: base64\r\n\r\naGVsbG8=",
    limits~,
  )
  assert_false(inventory.complete)
  assert_eq(inventory.decoded_total, 0)
  assert_eq(inventory.entities[0].decode_status, "unavailable")
  assert_true(inventory.entities[0].decode_error is Some(_))
}

///|
test "empty and unknown payloads are distinguished even when both have zero bytes" {
  let empty = @evidence.observe(b"Content-Transfer-Encoding: base64\r\n\r\n")
  assert_true(empty.complete)
  assert_eq(empty.entities[0].decoded_bytes, Some(0))
  let unknown = @evidence.observe(
    b"Content-Transfer-Encoding: x-private\r\n\r\n",
    mode=@model.Compatible,
  )
  assert_false(unknown.complete)
  assert_eq(unknown.entities[0].decoded_bytes, None)
  assert_eq(unknown.entities[0].decode_status, "unsupported")
}

///|
test "invalid transfer input retains a wire fingerprint and no fabricated decoded bytes" {
  let result = @evidence.observe(
    b"Content-Transfer-Encoding: base64\r\n\r\n!invalid",
    mode=@model.Compatible,
  )
  assert_false(result.complete)
  assert_eq(result.entities[0].decoded_sha256, None)
  assert_eq(result.entities[0].encoded_sha256.length(), 64)
}

///|
test "compatible raw quoted printable octets remain visibly recovered" {
  let result = @evidence.observe(
    b"Content-Transfer-Encoding: quoted-printable\r\n\r\nraw\xff\n",
    mode=@model.Compatible,
  )
  assert_eq(result.entities[0].decode_status, "recovered")
  assert_eq(result.entities[0].decoded_bytes, Some(5))
}

///|
test "multipart leaves share the total output budget in source order" {
  let raw = b"Content-Type: multipart/mixed; boundary=m\r\n\r\n--m\r\n\r\nabc\r\n--m\r\n\r\ndef\r\n--m--\r\n"
  let result = @evidence.observe(raw, limits={
    ..@model.ResourceLimits::secure_defaults(),
    max_decoded_leaf_bytes: 3,
    max_total_decoded_bytes: 5,
  })
  assert_false(result.complete)
  assert_eq(result.entities[1].path, [0])
  assert_eq(result.entities[1].decoded_bytes, Some(3))
  assert_eq(result.entities[2].path, [1])
  assert_eq(result.entities[2].decode_status, "unavailable")
  assert_eq(result.decoded_total, 3)
}
