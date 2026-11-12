# MoonMIME

MoonMIME is a bounded, byte-preserving MIME security inspection and protocol-test foundation written primarily in MoonBit. It accepts a complete RFC 5322-style message as `Bytes`, builds a recursive MIME entity tree, keeps source ranges into the original input, and surfaces ambiguity before a gateway, forensic tool, or test harness interprets content.

Version **0.4.0** adds raw/decoded inventories, manifest verification, caller-owned gateway rules, quota-checked batch decisions and independent parser/consumer validation.

Start with the [new capability guide](docs/DEEPENING.md), [3–5 minute demo](docs/DEMO.md) and [independent consumer](consumers/mailroom/README.md). No external adoption or complete mail-platform claim is made.

For release verification, see [2026-10-01 verification](docs/LOCAL_VERIFICATION_2026-10-01.md).

中文文档：[README_zh_CN.md](README_zh_CN.md)

维护验证使用官方 MoonBit 工具链，`moon` 版本为 `0.1.20261104`，编译器版本为 `v0.10.20+65efd5b93`。源码构建及 CI 请使用此版本或兼容的更新版本。

## Why MoonMIME

MoonMIME is not another mail-sending or convenience extraction library. It is a pre-interpretation layer for hostile `.eml`: it preserves ordered duplicates and raw byte ranges, rejects or reports parser-differential primitives, and applies independent resource budgets. Two complete, executable upper-layer workflows are documented in [integration cases](docs/INTEGRATION_CASES.md); the threat evidence and competitive boundary are recorded in [primary-source evidence](docs/SECURITY_FORENSICS_EVIDENCE.md) and [related work](docs/RELATED_WORK.md).

Published research demonstrates the need for this layer: CCS 2024 reported 180 successful evasions among 237 MIME candidates, while an IEEE SPW 2025 study produced 448 cross-parser differential samples. These are external research results, not MoonMIME measurements. MoonMIME's own reproducible results are 60/60 expected findings across six generated ambiguity classes, 20/20 finding-free controls, a 10-message review corpus with `TP=6 TN=4 FP=0 FN=0`, and 10,000 deterministic mutations on each of four targets with zero panic or hang. See [quantitative evidence](docs/QUANTITATIVE_EVIDENCE.md) for scope and limitations.

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
- Emits stable `moonmime.audit.v1` findings with severity, entity path, and exact evidence range.
- Detects conflicting singleton headers, path-bearing or executable attachment names, opaque encoded embedded messages, and non-canonical recovery.
- Provides CI policy via `audit --fail-on high` without decoding or writing attachments.
- Provides `integrations/gateway`, a reusable policy adapter plus a batch JSONL CLI for mail-ingestion allow/quarantine decisions.
- Provides `integrations/forensics`, a deterministic evidence sidecar with message and attachment-region SHA-256 bindings.
- Provides a portable core and a Native-only reference CLI.
- Inventories encoded source and decoded leaf SHA-256 separately, with shared decode budgets and explicit incomplete/opaque status.
- Rechecks forensic manifests against original bytes, including a canonical v1 sidecar verifier.
- Adds exact declared-media and filename rules, attachment quotas and ordered batch allow/quarantine/reject decisions.
- Runs 32 original fixtures through CPython `email` and MailParser: 24 normal agreements and 8 reviewed boundary observations; see [methodology](scripts/oracles/README.md).

## Install

```text
moon add oyjh0381/moonmime@0.4.0
```

The source checkout includes a `moon.work` connecting the independent consumer
module for development and integration verification.

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

The lower-level packages (`parser`, `header`, `media`, `transfer`, `query`, `report`, and `audit`) remain public for applications that need explicit control.

## Runnable upper-layer integrations

Mail gateway pre-ingestion gate:

```text
moon run --target native cmd/moonmime-gateway -- examples/integrations/gateway-clean.eml
moon run --target native cmd/moonmime-gateway -- examples/integrations/gateway-ambiguous.eml
```

The first input is allowed with exit 0. The second is quarantined with exit 3 and records conflicting identity, unsafe path, and executable-filename evidence.

Forensic evidence sidecar:

```text
moon run --target native cmd/moonmime-forensics -- CASE-2026-0042 examples/integrations/forensic-case.eml
```

This emits stable JSON binding the original message and its attachment source region with SHA-256 while retaining entity paths and byte ranges. See [the full case study](docs/INTEGRATION_CASES.md) and run `scripts/verify-integrations.sh` or `scripts/verify-integrations.ps1` for end-to-end assertions.

## CLI

The CLI is a Native adapter. Strict mode is the default:

```text
moon run --target native cmd/moonmime -- inspect examples/sample.eml --compatible
moon run --target native cmd/moonmime -- inspect examples/sample.eml --compatible --json
moon run --target native cmd/moonmime -- text examples/sample.eml --compatible
moon run --target native cmd/moonmime -- attachments examples/sample.eml --compatible
moon run --target native cmd/moonmime -- audit security-corpus/attack_conflicting_content_type.eml --compatible --json --fail-on high
```

`attachments` reports candidates only. `audit` returns exit code 3 when the configured finding threshold is reached. MoonMIME never creates files from untrusted attachment names.

## Strict and compatible modes

Strict mode rejects malformed line endings in headers, missing closing multipart boundaries, duplicate singleton MIME fields, unknown transfer encodings, invalid encoded-words, and damaged transfer encodings. Strict Quoted-Printable body decoding also rejects bare line endings and raw control/high bytes; compatible mode preserves them for inspection.

Compatible mode accepts a deliberately small set of common deviations and records structured diagnostics. It does not guess damaged Base64 bytes, repair ambiguous boundaries, or silently replace unsupported character sets.

## Resource defaults

The secure defaults cap input at 32 MiB, a header section at 256 KiB, a header line at 998 bytes, fields at 256, nesting depth at 16, entities at 1,000, one raw or decoded leaf at 16 MiB, and total decoded data at 64 MiB. `ResourceLimits` is validated before parsing.

## Build and test

```text
moon check --target all --deny-warn --warn-list=-implicit_impl_as_method-test_unqualified_package
moon test --target all --deny-warn --warn-list=-implicit_impl_as_method-test_unqualified_package
moon build --target all --deny-warn --warn-list=-implicit_impl_as_method-test_unqualified_package
moon fmt --check
moon info
bash scripts/evaluate-security-corpus.sh
bash scripts/verify-integrations.sh
moon run --target native --release cmd/moonmime-bench
```

The module defaults to the Native target so API documentation can include the reference CLIs. Portable packages, including both integration policy layers and SHA-256, are tested on all four backends. The repository includes unit, boundary, recovery, recursive integration, audit-matrix, deterministic mutation, reporting, corpus, and end-to-end workflow coverage. See [docs/TESTING.md](docs/TESTING.md).

## Scope and security

MoonMIME is a parser and inspection library, not an SMTP/IMAP client, malware scanner, HTML sanitizer, message authenticity verifier, or general MIME generator. Read [docs/SCOPE.md](docs/SCOPE.md), [docs/SECURITY.md](docs/SECURITY.md), and [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) before processing hostile mail.

## License

Apache License 2.0. Standards documents are referenced, not copied as implementation code. See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
