# MoonMIME

Bounded, byte-preserving MIME security inspection for MoonBit.

```moonbit nocheck
let message = @moonmime.parse(
  b"Subject: hello\r\nContent-Type: text/plain\r\n\r\nMoonBit",
)
inspect(message.root.media_type.essence(), content="text/plain")
```

Source revision 0.4.0 (local, unpublished) adds raw/decoded fingerprint inventories, forensic manifest verification, custom gateway rules and quota-checked batch decisions. A separate consumer module and development-only CPython/MailParser differential runner make the integration reproducible. The registry release remains 0.3.1.

The parser and integration packages do no network or filesystem I/O. Separate Native CLIs inspect/audit local `.eml`, evaluate gateway policy and emit/recheck forensic manifests. The new evidence inventory decodes under shared budgets and returns fingerprints, without writing attachment files.

See the repository README for the full guide, scope, resource limits, security model, standards matrix, and testing instructions. Licensed under Apache-2.0.
