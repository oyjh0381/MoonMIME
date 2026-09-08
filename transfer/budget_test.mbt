///|
fn budget_message() -> @model.InternetMessage raise {
  @parser.parse_message(
    @utf8.encode(
      "Content-Type: multipart/mixed; boundary=x\r\n\r\n--x\r\nContent-Transfer-Encoding: base64\r\n\r\nYWJj\r\n--x\r\nContent-Transfer-Encoding: base64\r\n\r\nZGVm\r\n--x--\r\n",
    ),
  )
}

///|
test "shared decode budget accumulates successful outputs" {
  let message = budget_message()
  let limits = {
    ..@model.ResourceLimits::secure_defaults(),
    max_decoded_leaf_bytes: 4,
    max_total_decoded_bytes: 6,
  }
  let budget = DecodeBudget::new(limits)
  let first = budget.decode_entity(
    message,
    message.root.children[0],
    @model.Strict,
  )
  let second = budget.decode_entity(
    message,
    message.root.children[1],
    @model.Strict,
  )
  assert_eq(@utf8.decode(first.bytes), "abc")
  assert_eq(@utf8.decode(second.bytes), "def")
  assert_eq(budget.consumed, 6)
  assert_eq(budget.remaining(), 0)
}

///|
test "shared decode budget rejects cumulative overflow" {
  let message = budget_message()
  let limits = {
    ..@model.ResourceLimits::secure_defaults(),
    max_decoded_leaf_bytes: 4,
    max_total_decoded_bytes: 5,
  }
  let budget = DecodeBudget::new(limits)
  ignore(budget.decode_entity(message, message.root.children[0], @model.Strict))
  let mut failed = false
  ignore(budget.decode_entity(message, message.root.children[1], @model.Strict)) catch {
    @model.DecodedOutputTooLarge(3, 2) => failed = true
    _ => ()
  }
  assert_true(failed)
  assert_eq(budget.consumed, 3)
}

///|
test "failed transfer decode does not consume shared budget" {
  let raw = @utf8.encode("Content-Transfer-Encoding: base64\r\n\r\n!!!!")
  let message = @parser.parse_message(raw)
  let budget = DecodeBudget::new(@model.ResourceLimits::secure_defaults())
  ignore(budget.decode_entity(message, message.root, @model.Strict)) catch {
    _ => ()
  }
  assert_eq(budget.consumed, 0)
}

///|
test "shared decode budget rejects containers" {
  let message = budget_message()
  let budget = DecodeBudget::new(@model.ResourceLimits::secure_defaults())
  let mut failed = false
  ignore(budget.decode_entity(message, message.root, @model.Strict)) catch {
    @model.InvalidArgument("decode budget accepts leaf entities only") =>
      failed = true
    _ => ()
  }
  assert_true(failed)
}
