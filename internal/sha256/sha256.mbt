///|
/// Return the lowercase SHA-256 digest of `input`.
///
/// This compact implementation exists so forensic manifests can bind their
/// structural observations to the exact original message bytes on every
/// MoonBit target without a platform crypto dependency.
pub fn digest_hex(input : Bytes) -> String {
  let padded = pad(input)
  let state : Array[UInt] = [
    0x6a09e667U, 0xbb67ae85U, 0x3c6ef372U, 0xa54ff53aU, 0x510e527fU, 0x9b05688cU,
    0x1f83d9abU, 0x5be0cd19U,
  ]
  let schedule = Array::make(64, 0U)
  let mut offset = 0
  while offset < padded.length() {
    for index in 0..<16 {
      let start = offset + index * 4
      schedule[index] = (padded[start].to_uint() << 24) |
        (padded[start + 1].to_uint() << 16) |
        (padded[start + 2].to_uint() << 8) |
        padded[start + 3].to_uint()
    }
    for index in 16..<64 {
      let s0 = rotate_right(schedule[index - 15], 7) ^
        rotate_right(schedule[index - 15], 18) ^
        (schedule[index - 15] >> 3)
      let s1 = rotate_right(schedule[index - 2], 17) ^
        rotate_right(schedule[index - 2], 19) ^
        (schedule[index - 2] >> 10)
      schedule[index] = schedule[index - 16] + s0 + schedule[index - 7] + s1
    }
    compress(state, schedule)
    offset = offset + 64
  }
  let builder = StringBuilder()
  for word in state {
    for shift in [28, 24, 20, 16, 12, 8, 4, 0] {
      builder.write_string(
        hex_digit(((word >> shift) & 0xfU).reinterpret_as_int()),
      )
    }
  }
  builder.to_string()
}

///|
fn pad(input : Bytes) -> Bytes {
  let bit_length = Int::to_uint64(input.length()) * 8UL
  let zero_count = (55 - input.length() % 64 + 64) % 64
  let output : Array[Byte] = []
  for byte in input {
    output.push(byte)
  }
  output.push(b'\x80')
  for _ in 0..<zero_count {
    output.push(b'\x00')
  }
  for shift in [56, 48, 40, 32, 24, 16, 8, 0] {
    output.push(((bit_length >> shift) & 0xffUL).to_byte())
  }
  Bytes::from_array(output)
}

///|
fn compress(state : Array[UInt], schedule : Array[UInt]) -> Unit {
  let constants : Array[UInt] = [
    0x428a2f98U, 0x71374491U, 0xb5c0fbcfU, 0xe9b5dba5U, 0x3956c25bU, 0x59f111f1U,
    0x923f82a4U, 0xab1c5ed5U, 0xd807aa98U, 0x12835b01U, 0x243185beU, 0x550c7dc3U,
    0x72be5d74U, 0x80deb1feU, 0x9bdc06a7U, 0xc19bf174U, 0xe49b69c1U, 0xefbe4786U,
    0x0fc19dc6U, 0x240ca1ccU, 0x2de92c6fU, 0x4a7484aaU, 0x5cb0a9dcU, 0x76f988daU,
    0x983e5152U, 0xa831c66dU, 0xb00327c8U, 0xbf597fc7U, 0xc6e00bf3U, 0xd5a79147U,
    0x06ca6351U, 0x14292967U, 0x27b70a85U, 0x2e1b2138U, 0x4d2c6dfcU, 0x53380d13U,
    0x650a7354U, 0x766a0abbU, 0x81c2c92eU, 0x92722c85U, 0xa2bfe8a1U, 0xa81a664bU,
    0xc24b8b70U, 0xc76c51a3U, 0xd192e819U, 0xd6990624U, 0xf40e3585U, 0x106aa070U,
    0x19a4c116U, 0x1e376c08U, 0x2748774cU, 0x34b0bcb5U, 0x391c0cb3U, 0x4ed8aa4aU,
    0x5b9cca4fU, 0x682e6ff3U, 0x748f82eeU, 0x78a5636fU, 0x84c87814U, 0x8cc70208U,
    0x90befffaU, 0xa4506cebU, 0xbef9a3f7U, 0xc67178f2U,
  ]
  let mut a = state[0]
  let mut b = state[1]
  let mut c = state[2]
  let mut d = state[3]
  let mut e = state[4]
  let mut f = state[5]
  let mut g = state[6]
  let mut h = state[7]
  for index in 0..<64 {
    let sum1 = rotate_right(e, 6) ^ rotate_right(e, 11) ^ rotate_right(e, 25)
    let choice = (e & f) ^ (e.lnot() & g)
    let temp1 = h + sum1 + choice + constants[index] + schedule[index]
    let sum0 = rotate_right(a, 2) ^ rotate_right(a, 13) ^ rotate_right(a, 22)
    let majority = (a & b) ^ (a & c) ^ (b & c)
    let temp2 = sum0 + majority
    h = g
    g = f
    f = e
    e = d + temp1
    d = c
    c = b
    b = a
    a = temp1 + temp2
  }
  state[0] = state[0] + a
  state[1] = state[1] + b
  state[2] = state[2] + c
  state[3] = state[3] + d
  state[4] = state[4] + e
  state[5] = state[5] + f
  state[6] = state[6] + g
  state[7] = state[7] + h
}

///|
fn rotate_right(value : UInt, count : Int) -> UInt {
  (value >> count) | (value << (32 - count))
}

///|
fn hex_digit(value : Int) -> String {
  if value < 10 {
    value.to_string()
  } else {
    Int::unsafe_to_char('a'.to_int() + value - 10).to_string()
  }
}
