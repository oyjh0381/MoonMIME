///|
extern "C" fn process_exit(code : Int) = "exit"

///|
async fn main {
  let args = @env.args()
  if args.length() < 3 {
    @stdio.stderr.write(
      "usage: moonmime-forensics <case-id> <message.eml> [message.eml ...]\n",
    )
    process_exit(2)
    return
  }
  let case_id = args[1]
  let mut failed = false
  for index in 2..<args.length() {
    let path = args[index]
    try {
      let bytes : Bytes = @fs.read_file(path).binary()
      let manifest = @forensics.build_manifest(bytes, case_id, path)
      @stdio.stdout.write(@forensics.render_json(manifest) + "\n")
    } catch {
      error => {
        failed = true
        @stdio.stderr.write(path + ": \{error}\n")
      }
    }
  }
  if failed {
    process_exit(2)
  }
}
