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
       -> ambiguity and extraction-risk audit layer
       -> gateway decision + forensic manifest integration layers
       -> Native CLI adapters
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
- `audit`: deterministic security findings, evidence ranges, severity, and CI policy.
- `internal/sha256`: portable evidence hashing with standard-vector tests.
- `integrations/gateway`: mail-ingestion policy decision and JSONL record.
- `integrations/forensics`: byte-bound evidence manifest and JSON sidecar.
- root package: small high-level API facade.
- `cmd/*`: Native filesystem/stdio adapters only.

## Core invariants

1. Every stored range is half-open and indexes the immutable original `Bytes`.
2. Parsing never requires transfer decoding; decoded payload is a separate value.
3. A delimiter matches only at a physical-line start and only with valid trailing syntax.
4. Resource limits are checked before unbounded allocation or recursion.
5. Strict failures are structured `MimeError` values; compatible recovery is observable.
6. Entity paths are deterministic child-index arrays and do not depend on filenames.
7. Audit consumes parsed metadata only; it never decodes or executes content.
8. Integration packages return data only; transport, queue, and evidence-store mutation stay in caller-owned adapters.

## Complexity

Header and boundary scans are linear in the bytes of their bounded region. Because each nested multipart level scans its own enclosing body, recursive parsing is `O(n * d)` in the worst case for `n` input bytes and nesting depth `d`; the default bound fixes `d <= 16`, so ordinary bounded workloads behave linearly. Retained space is `O(n + e)` for raw bytes, fields, and `e` entities. Query traversal is `O(e)`. Base64 and Quoted-Printable decoding are `O(b)` time and output space for a body of `b` bytes.

The complete input is retained intentionally to guarantee byte ranges. Applications needing streaming multi-GiB processing should not use v0.3.
