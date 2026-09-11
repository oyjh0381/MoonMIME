///|
/// Reproducible in-process parser/auditor throughput probe.
/// It uses synthetic text bodies and emits CSV; it is not a microbenchmark of
/// transfer decoding or filesystem I/O. The multipart body forces a complete
/// boundary scan so input-size growth is actually exercised.
async fn main {
  @stdio.stdout.write("bytes,iterations,elapsed_ms,mib_per_second,checksum\n")
  run_case(64 * 1024, 2000)
  run_case(256 * 1024, 500)
  run_case(1024 * 1024, 128)
  run_case(4 * 1024 * 1024, 32)
}

///|
async fn run_case(size : Int, iterations : Int) -> Unit {
  let input = make_message(size)
  // Warm the generated code and allocator before timing.
  ignore(@audit.audit_message(@parser.parse_message(input)))
  let start = @async.now()
  let mut checksum = 0
  for _ in 0..<iterations {
    let message = @parser.parse_message(input)
    let report = @audit.audit_message(message)
    checksum = checksum + message.stats.raw_bytes + report.risk_score
  }
  let elapsed = @async.now() - start
  let total_mib = size.to_double() * iterations.to_double() / 1048576.0
  let seconds = elapsed.to_double() / 1000.0
  let throughput = if seconds > 0.0 { total_mib / seconds } else { 0.0 }
  @stdio.stdout.write(
    size.to_string() +
    "," +
    iterations.to_string() +
    "," +
    elapsed.to_string() +
    "," +
    throughput.to_string() +
    "," +
    checksum.to_string() +
    "\n",
  )
}

///|
fn make_message(size : Int) -> Bytes {
  let prefix = @utf8.encode(
    "From: benchmark@example.test\r\nSubject: deterministic throughput probe\r\nContent-Type: multipart/mixed; boundary=bench\r\n\r\n--bench\r\nContent-Type: text/plain\r\n\r\n",
  )
  let suffix = @utf8.encode("\r\n--bench--\r\n")
  let bytes : Array[Byte] = []
  for byte in prefix {
    bytes.push(byte)
  }
  while bytes.length() + suffix.length() < size {
    bytes.push(b'a')
  }
  for byte in suffix {
    bytes.push(byte)
  }
  Bytes::from_array(bytes)
}
