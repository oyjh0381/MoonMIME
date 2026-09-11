# MoonMIME

Bounded, byte-preserving MIME security inspection for MoonBit.

```moonbit nocheck
let message = @moonmime.parse(
  b"Subject: hello\r\nContent-Type: text/plain\r\n\r\nMoonBit",
)
inspect(message.root.media_type.essence(), content="text/plain")
```

v0.3 adds two runnable upper-layer integrations to the deterministic security audit layer: a mail-gateway policy adapter that emits batch JSONL decisions, and a forensic sidecar that binds the exact message and attachment source regions with SHA-256. Both are portable library packages with Native reference CLIs and cross-platform end-to-end verification.

The parser and integration packages do no network or filesystem I/O. Separate Native CLIs inspect or audit local `.eml` files, evaluate gateway policy, and emit forensic manifests without decoding or extracting attachments.

See the repository README for the full guide, scope, resource limits, security model, standards matrix, and testing instructions. Licensed under Apache-2.0.
