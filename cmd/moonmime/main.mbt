///|
extern "C" fn process_exit(code : Int) = "exit"

///|
async fn main {
  let args = @env.args()
  try {
    if args.length() < 2 {
      print_usage()
      process_exit(2)
      return
    }
    match args[1] {
      "inspect" => run_inspect(args)
      "text" => run_text(args)
      "attachments" => run_attachments(args)
      "audit" => run_audit(args)
      "version" | "--version" | "-V" => @stdio.stdout.write("moonmime 0.2.0\n")
      "help" | "--help" | "-h" => print_usage()
      command => raise @model.InvalidArgument("unknown command: " + command)
    }
  } catch {
    @model.InvalidArgument(message) =>
      fail_mime(@model.InvalidArgument(message))
    @model.InputTooLarge(a, b) => fail_mime(@model.InputTooLarge(a, b))
    @model.HeaderSectionTooLarge(a, b) =>
      fail_mime(@model.HeaderSectionTooLarge(a, b))
    @model.HeaderLineTooLong(a, b) => fail_mime(@model.HeaderLineTooLong(a, b))
    @model.HeaderCountExceeded(a, b) =>
      fail_mime(@model.HeaderCountExceeded(a, b))
    @model.MalformedHeader(a, b) => fail_mime(@model.MalformedHeader(a, b))
    @model.MissingHeaderTerminator(a) =>
      fail_mime(@model.MissingHeaderTerminator(a))
    @model.InvalidMediaType(message) =>
      fail_mime(@model.InvalidMediaType(message))
    @model.InvalidDisposition(message) =>
      fail_mime(@model.InvalidDisposition(message))
    @model.InvalidParameter(message) =>
      fail_mime(@model.InvalidParameter(message))
    @model.InvalidBoundary(message) =>
      fail_mime(@model.InvalidBoundary(message))
    @model.MissingBoundary(message) =>
      fail_mime(@model.MissingBoundary(message))
    @model.MissingClosingBoundary(message) =>
      fail_mime(@model.MissingClosingBoundary(message))
    @model.RecursionLimitExceeded(a, b) =>
      fail_mime(@model.RecursionLimitExceeded(a, b))
    @model.EntityCountExceeded(a, b) =>
      fail_mime(@model.EntityCountExceeded(a, b))
    @model.LeafBodyTooLarge(a, b) => fail_mime(@model.LeafBodyTooLarge(a, b))
    @model.DecodedOutputTooLarge(a, b) =>
      fail_mime(@model.DecodedOutputTooLarge(a, b))
    @model.InvalidBase64(a, b) => fail_mime(@model.InvalidBase64(a, b))
    @model.InvalidQuotedPrintable(a, b) =>
      fail_mime(@model.InvalidQuotedPrintable(a, b))
    @model.UnsupportedTransferEncoding(message) =>
      fail_mime(@model.UnsupportedTransferEncoding(message))
    @model.UnsupportedCharset(message) =>
      fail_mime(@model.UnsupportedCharset(message))
    @model.InvalidEncodedWord(message) =>
      fail_mime(@model.InvalidEncodedWord(message))
    @model.InvalidByteRange(a, b, c) =>
      fail_mime(@model.InvalidByteRange(a, b, c))
    @model.IoFailure(message) => fail_mime(@model.IoFailure(message))
    error => fail_with("MOONMIME_INTERNAL", "\{error}", 70)
  }
}

///|
async fn run_audit(args : Array[String]) -> Unit {
  require_command_args(
    args, "usage: moonmime audit <message.eml> [--compatible] [--json] [--fail-on high|medium|low|info]",
  )
  let mode = parse_mode(args)
  let message = load_message(args[2], mode)
  let audit = @audit.audit_message(message)
  if has_option(args, "--json") {
    @stdio.stdout.write(@audit.render_json(audit) + "\n")
  } else {
    @stdio.stdout.write(@audit.render_summary(audit))
  }
  match parse_fail_threshold(args) {
    Some(threshold) => if audit.has_at_least(threshold) { process_exit(3) }
    None => ()
  }
}

///|
fn parse_fail_threshold(
  args : Array[String],
) -> @audit.AuditSeverity? raise @model.MimeError {
  for index in 3..<args.length() {
    if args[index] == "--fail-on" {
      if index + 1 >= args.length() {
        raise @model.InvalidArgument("--fail-on requires a severity")
      }
      return Some(
        match args[index + 1] {
          "high" => @audit.High
          "medium" => @audit.Medium
          "low" => @audit.Low
          "info" => @audit.Info
          value =>
            raise @model.InvalidArgument("unknown audit severity: " + value)
        },
      )
    }
  }
  None
}

///|
async fn run_inspect(args : Array[String]) -> Unit {
  require_command_args(
    args, "usage: moonmime inspect <message.eml> [--compatible] [--json]",
  )
  let mode = parse_mode(args)
  let message = load_message(args[2], mode)
  if has_option(args, "--json") {
    @stdio.stdout.write(@report.render_json(message) + "\n")
  } else {
    @stdio.stdout.write(@report.render_summary(message))
  }
}

///|
async fn run_text(args : Array[String]) -> Unit {
  require_command_args(
    args, "usage: moonmime text <message.eml> [--compatible]",
  )
  reject_option(args, "--json", "--json is available only for inspect")
  let message = load_message(args[2], parse_mode(args))
  match @query.preferred_text(message, mode=parse_mode(args)) {
    Some(selection) => {
      @stdio.stdout.write(selection.text)
      if !selection.text.has_suffix("\n") {
        @stdio.stdout.write("\n")
      }
    }
    None =>
      raise @model.InvalidArgument(
        "message has no displayable text/plain or text/html body",
      )
  }
}

///|
async fn run_attachments(args : Array[String]) -> Unit {
  require_command_args(
    args, "usage: moonmime attachments <message.eml> [--compatible]",
  )
  reject_option(args, "--json", "--json is available only for inspect")
  let message = load_message(args[2], parse_mode(args))
  let found = @query.attachments(message)
  if found.is_empty() {
    @stdio.stdout.write("no attachment candidates\n")
    return
  }
  for item in found {
    let filename = match item.filename {
      Some(value) => value
      None => "<unnamed>"
    }
    @stdio.stdout.write(
      render_path(item.path) +
      "\t" +
      item.media_type +
      "\t" +
      item.raw_size.to_string() +
      "\t" +
      filename +
      "\n",
    )
  }
}

///|
async fn load_message(
  path : String,
  mode : @model.ParseMode,
) -> @model.InternetMessage {
  let bytes : Bytes = @fs.read_file(path).binary() catch {
    error => raise @model.IoFailure("cannot read " + path + ": \{error}")
  }
  @parser.parse_message(bytes, mode~)
}

///|
fn parse_mode(args : Array[String]) -> @model.ParseMode raise @model.MimeError {
  validate_options(args)
  if has_option(args, "--compatible") {
    @model.Compatible
  } else {
    @model.Strict
  }
}

///|
fn validate_options(args : Array[String]) -> Unit raise @model.MimeError {
  for index in 3..<args.length() {
    match args[index] {
      "--compatible"
      | "--json"
      | "--fail-on"
      | "high"
      | "medium"
      | "low"
      | "info" => ()
      option => raise @model.InvalidArgument("unknown option: " + option)
    }
  }
}

///|
fn has_option(args : Array[String], option : String) -> Bool {
  for index in 3..<args.length() {
    if args[index] == option {
      return true
    }
  }
  false
}

///|
fn reject_option(
  args : Array[String],
  option : String,
  message : String,
) -> Unit raise @model.MimeError {
  if has_option(args, option) {
    raise @model.InvalidArgument(message)
  }
}

///|
fn require_command_args(
  args : Array[String],
  usage : String,
) -> Unit raise @model.MimeError {
  if args.length() < 3 {
    raise @model.InvalidArgument(usage)
  }
}

///|
fn render_path(path : Array[Int]) -> String {
  if path.is_empty() {
    return "."
  }
  let builder = StringBuilder()
  for index in 0..<path.length() {
    if index > 0 {
      builder.write_char('.')
    }
    builder.write_string(path[index].to_string())
  }
  builder.to_string()
}

///|
async fn print_usage() -> Unit {
  @stdio.stdout.write(
    (
      #|MoonMIME — bounded, byte-preserving MIME inspection for MoonBit
      #|
      #|Usage:
      #|  moonmime inspect <message.eml> [--compatible] [--json]
      #|  moonmime text <message.eml> [--compatible]
      #|  moonmime attachments <message.eml> [--compatible]
      #|  moonmime audit <message.eml> [--compatible] [--json] [--fail-on severity]
      #|  moonmime version
      #|  moonmime help
      #|
      #|Strict mode is the default. The tool never extracts attachment files.
      #|
    ),
  )
}

///|
async fn fail_mime(error : @model.MimeError) -> Unit {
  fail_with(error.code(), error.message(), error.exit_code())
}

///|
async fn fail_with(code : String, message : String, status : Int) -> Unit {
  @stdio.stderr.write(code + ": " + message + "\n")
  process_exit(status)
}
