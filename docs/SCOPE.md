# MoonMIME v0.1 Scope

MoonMIME v0.1 parses raw `.eml`-style messages, interprets recursive MIME
structure, decodes Base64 and Quoted-Printable transfer encodings, selects
display text, enumerates attachments, and emits deterministic reports.

The core accepts `Bytes` and is backend-portable. It preserves original bytes
and keeps transfer decoding separate from character-set decoding.

## Non-goals

- SMTP or IMAP clients and servers
- message delivery, spam filtering, malware scanning, or trusted storage
- arbitrary character-set conversion
- a general MIME message generator
- repairing corrupt boundaries or transfer encodings without diagnostics

