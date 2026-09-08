# MoonMIME

MoonMIME is a bounded, byte-preserving MIME message parser and inspection toolkit written primarily in MoonBit. It accepts a complete RFC 5322-style message as `Bytes`, builds a recursive MIME entity tree, keeps source ranges into the original input, and performs transfer or character-set decoding only when requested.

> Status: v0.1.0 release candidate. GitHub publication and mooncakes.io publication are intentionally pending project-owner approval.

中文文档：[README_zh_CN.md](README_zh_CN.md)

## Why MoonMIME

MoonBit already has HTTP `multipart/form-data` implementations. MoonMIME addresses a different layer: complete Internet messages and recursive MIME entities, including folded headers, `message/rfc822`, Base64, Quoted-Printable, RFC 2047 encoded-words, and RFC 2231 parameter continuations. The evidence and boundary comparison are recorded in [docs/RELATED_WORK.md](docs/RELATED_WORK.md).

## Capabilities

- Parses ordered, duplicate-preserving RFC 5322-style header sections.
- Builds nested `multipart/*` and `message/rfc822` entity trees.
- Preserves the complete raw input and half-open source byte ranges.
- Decodes MIME Base64 and Quoted-Printable with bounded allocation.
- Decodes RFC 2047 `B`/`Q` encoded-words.
- Resolves RFC 2231 extended and continued media parameters.
- Supports strict and compatible parse modes with structured diagnostics.
- Enumerates attachment candidates without trusting or writing filenames.
- Selects a preferred `text/plain`, then `text/html`, display body.
- Emits stable `moonmime.inspect.v1` JSON and terminal summaries.
- Provides a portable core and a Native-only reference CLI.

## Install

The package is not published yet. From this repository, use the package path `oyjh0381/moonmime`. After owner-approved publication, installation will be:

```text
moon add oyjh0381/moonmime@0.1.0
```

## Library quick start

```moonbit
///|
test "inspect a message" {
  let raw = b"Subject: hello\r\nContent-Type: text/plain\r\n\r\nMoonBit"
  let message = @moonmime.parse(raw)
  inspect(message.root.media_type.essence(), content="text/plain")
  inspect(message.stats.entities, content="1")
}
```

Use `parse_with` to select compatibility recovery and explicit limits:

```moonbit
let limits = @moonmime.edge_limits()
let message = @moonmime.parse_with(raw, @model.Compatible, limits)
```

The lower-level packages (`parser`, `header`, `media`, `transfer`, `query`, and `report`) remain public for applications that need explicit control.

## CLI

The CLI is a Native adapter. Strict mode is the default:

```text
moon run --target native cmd/moonmime -- inspect examples/sample.eml --compatible
moon run --target native cmd/moonmime -- inspect examples/sample.eml --compatible --json
moon run --target native cmd/moonmime -- text examples/sample.eml --compatible
moon run --target native cmd/moonmime -- attachments examples/sample.eml --compatible
```

`attachments` reports candidates only. v0.1 never creates files from untrusted attachment names.

## Strict and compatible modes

Strict mode rejects malformed line endings in headers, missing closing multipart boundaries, duplicate singleton MIME fields, unknown transfer encodings, invalid encoded-words, and damaged transfer encodings.

Compatible mode accepts a deliberately small set of common deviations and records structured diagnostics. It does not guess damaged Base64 bytes, repair ambiguous boundaries, or silently replace unsupported character sets.

## Resource defaults

The secure defaults cap input at 32 MiB, a header section at 256 KiB, a header line at 998 bytes, fields at 256, nesting depth at 16, entities at 1,000, one raw or decoded leaf at 16 MiB, and total decoded data at 64 MiB. `ResourceLimits` is validated before parsing.

## Build and test

```text
moon check --target all --deny-warn
moon test --target all --deny-warn
moon build --target all
moon fmt --check
moon info
```

The repository includes unit, boundary, recovery, recursive integration, reporting, and CLI smoke coverage. See [docs/TESTING.md](docs/TESTING.md).

## Scope and security

MoonMIME is a parser and inspection library, not an SMTP/IMAP client, malware scanner, HTML sanitizer, message authenticity verifier, or general MIME generator. Read [docs/SCOPE.md](docs/SCOPE.md), [docs/SECURITY.md](docs/SECURITY.md), and [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) before processing hostile mail.

## License

Apache License 2.0. Standards documents are referenced, not copied as implementation code. See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
