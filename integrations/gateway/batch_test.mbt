///|
test "batch preserves successful decisions beside explicit parse rejections" {
  let batch = @gateway.evaluate_batch(
    [
      { source_id: "ok", input: b"Subject: clean\r\n\r\nhello", },
      { source_id: "bad", input: b"not a header", },
    ],
    @gateway.GatewayRules::default(),
  )
  assert_eq(batch.allowed, 1)
  assert_eq(batch.rejected, 1)
  assert_eq(batch.results[0].source_id, "ok")
  assert_eq(batch.results[1].source_id, "bad")
  assert_true(batch.results[1].error_code is Some(_))
}

///|
test "batch resource preflight rejects aggregate overflow before decisions" {
  let inputs : Array[@gateway.GatewayInput] = [
    { source_id: "a", input: b"\r\na", },
    { source_id: "b", input: b"\r\nb", },
  ]
  let exact = @gateway.evaluate_batch(
    inputs,
    @gateway.GatewayRules::default(),
    max_total_input_bytes=6,
  )
  assert_eq(exact.allowed, 2)
  let rejected = try {
    ignore(
      @gateway.evaluate_batch(
        inputs,
        @gateway.GatewayRules::default(),
        max_total_input_bytes=5,
      ),
    )
    false
  } catch {
    _ => true
  }
  assert_true(rejected)
}

///|
test "batch refuses duplicate source labels and too many messages" {
  let inputs : Array[@gateway.GatewayInput] = [
    { source_id: "same", input: b"\r\na", },
    { source_id: "same", input: b"\r\nb", },
  ]
  let duplicate = try {
    ignore(@gateway.evaluate_batch(inputs, @gateway.GatewayRules::default()))
    false
  } catch {
    _ => true
  }
  assert_true(duplicate)
  let count = try {
    ignore(
      @gateway.evaluate_batch(
        inputs,
        @gateway.GatewayRules::default(),
        max_messages=1,
      ),
    )
    false
  } catch {
    _ => true
  }
  assert_true(count)
}
