# MoonMIME

Bounded, byte-preserving recursive MIME parsing for MoonBit.

```moonbit
let message = @moonmime.parse(
  b"Subject: hello\r\nContent-Type: text/plain\r\n\r\nMoonBit",
)
inspect(message.root.media_type.essence(), content="text/plain")
```

v0.1 parses ordered and folded headers, recursive `multipart/*`, direct `message/rfc822`, Base64, Quoted-Printable, RFC 2047 encoded-words, and RFC 2231 extended parameters. It exposes source byte ranges, strict/compatible modes, structured errors and diagnostics, attachment metadata, preferred display text, and deterministic JSON/text reports.

The parser does no network or filesystem I/O. The separate Native CLI can inspect a local `.eml` file, print display text, or enumerate attachments; it never extracts attachment files.

See the repository README for the full guide, scope, resource limits, security model, standards matrix, and testing instructions. Licensed under Apache-2.0.
