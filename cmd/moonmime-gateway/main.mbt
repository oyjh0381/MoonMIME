///|
extern "C" fn process_exit(code : Int) = "exit"

///|
async fn main {
  let args = @env.args()
  if args.length() < 2 {
    @stdio.stderr.write(
      "usage: moonmime-gateway <message.eml> [message.eml ...]\n",
    )
    process_exit(2)
    return
  }
  let mut blocked = false
  for index in 1..<args.length() {
    let path = args[index]
    let line = try {
      let bytes : Bytes = @fs.read_file(path).binary()
      let decision = @gateway.evaluate(bytes, path)
      if decision.action == @gateway.Quarantine {
        blocked = true
      }
      @gateway.render_json(decision)
    } catch {
      error => {
        blocked = true
        @gateway.render_error_json(path, "\{error}")
      }
    }
    @stdio.stdout.write(line + "\n")
  }
  if blocked {
    process_exit(3)
  }
}
