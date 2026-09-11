# MoonMIME

Bounded, byte-preserving MIME security inspection for MoonBit.

```moonbit nocheck
let message = @moonmime.parse(
  b"Subject: hello\r\nContent-Type: text/plain\r\n\r\nMoonBit",
)
inspect(message.root.media_type.essence(), content="text/plain")
```

v0.2 adds a deterministic security audit layer over ordered and folded headers, recursive `multipart/*`, direct `message/rfc822`, Base64, Quoted-Printable, RFC 2047 encoded-words, and RFC 2231 extended parameters. Findings identify parser ambiguity and unsafe extraction metadata with a stable code, severity, entity path, and exact source byte range.

The parser does no network or filesystem I/O. The separate Native CLI can inspect or audit a local `.eml`; `audit --fail-on high` supports quarantine/CI policy without decoding or extracting attachments.

See the repository README for the full guide, scope, resource limits, security model, standards matrix, and testing instructions. Licensed under Apache-2.0.
