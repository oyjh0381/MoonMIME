# Architecture

MoonMIME separates byte structure, MIME semantics, decoding, querying, reporting, and I/O.

```text
Bytes
  -> header + media primitives
  -> entity metadata
  -> recursive parser
  -> InternetMessage(raw bytes, ranges, tree, diagnostics, stats)
       -> transfer decoder
       -> read-only query layer
       -> deterministic report layer
       -> Native CLI adapter
```

## Packages

- `model`: shared domain types, errors, diagnostics, and resource limits.
- `internal/bytesutil`: ASCII classification, physical-line scanning, and safe ranges.
- `header`: header blocks and RFC 2047 encoded-words.
- `media`: media/disposition parsing and RFC 2231 parameter resolution.
- `entity`: semantic interpretation of MIME singleton fields.
- `parser`: exact boundary scanning and recursive entity-tree construction.
- `transfer`: Base64, Quoted-Printable, and identity transfer decoding.
- `query`: depth-first lookup, attachments, subject, and display text.
- `report`: stable JSON schema and terminal summary.
- root package: small high-level API facade.
- `cmd/moonmime`: Native filesystem/stdio adapter only.

## Core invariants

1. Every stored range is half-open and indexes the immutable original `Bytes`.
2. Parsing never requires transfer decoding; decoded payload is a separate value.
3. A delimiter matches only at a physical-line start and only with valid trailing syntax.
4. Resource limits are checked before unbounded allocation or recursion.
5. Strict failures are structured `MimeError` values; compatible recovery is observable.
6. Entity paths are deterministic child-index arrays and do not depend on filenames.

## Complexity

Header and boundary scans are linear in the bytes of their bounded region. Recursive parsing scans each multipart body once and parses each child once, for expected `O(n)` time in total message bytes and `O(n + e)` retained space for raw bytes, fields, and `e` entities. Query traversal is `O(e)`. Base64 and Quoted-Printable decoding are `O(b)` time and output space for a body of `b` bytes.

The complete input is retained intentionally to guarantee byte ranges. Applications needing streaming multi-GiB processing should not use v0.1.
