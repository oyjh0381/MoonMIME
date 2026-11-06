///|
extern "C" fn process_exit(code : Int32) = "exit"

///|
// Read at most limit+1 bytes even if a file grows after open. Always close.
async fn read_bounded(path : String, limit : Int32) -> Bytes {
  let file = @fs.open(path, mode=@fs.ReadOnly)
  defer file.close()
  let size = file.size()
  if size > limit.to_int64() {
    raise @model.InputTooLarge(limit + 1, limit)
  }
  let buffer = FixedArray::make(size.to_int() + 1, b'\x00')
  let mut received = 0
  while received < buffer.length() {
    let count = file.read_at(
      buffer,
      position=received.to_int64(),
      offset=received,
      len=buffer.length() - received,
    )
    if count == 0 {
      break
    }
    received += count
  }
  if received > limit {
    raise @model.InputTooLarge(received, limit)
  }
  if received.to_int64() != size {
    raise @model.IoFailure("file changed while reading")
  }
  Bytes::from_array(buffer)[0:received].to_owned()
}

///|
async fn main {
  let args = @env.args()
  try {
    if args.length() < 3 {
      raise @model.InvalidArgument(
        "usage: moonmime-evidence inventory FILE [--compatible] | capture FILE CASE SOURCE | verify FILE SIDECAR CASE SOURCE",
      )
    }
    let raw = read_bounded(args[2], 32 * 1024 * 1024)
    match args[1] {
      "inventory" => {
        if args.length() != 3 &&
          !(args.length() == 4 && args[3] == "--compatible") {
          raise @model.InvalidArgument("inventory FILE [--compatible]")
        }
        let mode = if args.length() == 4 {
          @model.Compatible
        } else {
          @model.Strict
        }
        @stdio.stdout.write(
          @evidence.render_json(@evidence.observe(raw, mode~)) + "\n",
        )
      }
      "capture" => {
        if args.length() != 5 {
          raise @model.InvalidArgument("capture FILE CASE SOURCE")
        }
        @stdio.stdout.write(
          @forensics.render_json(
            @forensics.build_manifest(raw, args[3], args[4]),
          ) +
          "\n",
        )
      }
      "verify" => {
        if args.length() != 6 {
          raise @model.InvalidArgument("verify FILE SIDECAR CASE SOURCE")
        }
        let sidecar = @utf8.decode(read_bounded(args[3], 16 * 1024 * 1024))
        let result = @forensics.verify_sidecar(raw, sidecar, args[4], args[5])
        @stdio.stdout.write(@forensics.verification_json(result) + "\n")
        if !result.valid {
          process_exit(3)
        }
      }
      _ => raise @model.InvalidArgument("unknown evidence command")
    }
  } catch {
    error => {
      let output : Json = {
        "schema": "moonmime.error.v1",
        "error": Json::string("\{error}"),
      }
      @stdio.stdout.write(output.stringify() + "\n")
      process_exit(2)
    }
  }
}
