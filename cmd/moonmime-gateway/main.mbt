///|
extern "C" fn process_exit(code : Int) = "exit"

///|
async fn main {
  let args = @env.args()
  if args.length() < 2 {
    @stdio.stderr.write(
      "usage: moonmime-gateway [--quarantine-on severity] <message.eml> [message.eml ...]\n",
    )
    process_exit(2)
    return
  }
  let paths : Array[String] = []
  let mut threshold = @audit.Medium
  let mut index = 1
  while index < args.length() {
    if args[index] == "--quarantine-on" {
      if index + 1 >= args.length() {
        @stdio.stderr.write("--quarantine-on requires a severity\n")
        process_exit(2)
        return
      }
      threshold = match args[index + 1] {
        "high" => @audit.High
        "medium" => @audit.Medium
        "low" => @audit.Low
        "info" => @audit.Info
        value => {
          @stdio.stderr.write("unknown severity: " + value + "\n")
          process_exit(2)
          return
        }
      }
      index = index + 2
    } else if args[index].has_prefix("--") {
      @stdio.stderr.write("unknown option: " + args[index] + "\n")
      process_exit(2)
      return
    } else {
      paths.push(args[index])
      index = index + 1
    }
  }
  if paths.is_empty() {
    @stdio.stderr.write("at least one message path is required\n")
    process_exit(2)
    return
  }
  let base_policy = @gateway.GatewayPolicy::recommended()
  let policy : @gateway.GatewayPolicy = {
    mode: base_policy.mode,
    quarantine_on: threshold,
    limits: base_policy.limits,
  }
  let mut blocked = false
  for path in paths {
    let line = try {
      let bytes : Bytes = @fs.read_file(path).binary()
      let decision = @gateway.evaluate(bytes, path, policy~)
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
