# Related Work and Ecosystem Boundary

Research snapshot: 2026-09-11. Sources are the current Mooncakes metadata and each project's repository README. This comparison acknowledges overlap rather than claiming uniqueness.

## Feature boundary at a glance

| Capability / primary goal | MoonMIME v0.2 | mailkit_12314 | mbt-email | MoonPart |
|---|---|---|---|---|
| Complete email/MIME parse | Yes | Yes | Yes | No (HTTP form-data) |
| Address/date/message construction | No | Address + analysis helpers | Address + serialization | No |
| Mailbox/DSN/classification workflow | No | Yes | No | No |
| Byte-preserved original + source ranges | **Core contract** | Not a published primary contract | String AST/serialization | Raw streaming events for HTTP bodies |
| Parser-ambiguity audit with stable evidence ranges | **Yes (`moonmime.audit.v1`)** | Security signals/policy checks, different workflow | Not advertised | No |
| Strict/compatible recovery as differential oracle | **Yes** | Not advertised as primary API | Not advertised | Strict HTTP parser |
| Per-input/header/line/depth/entity/decode budgets | **Yes** | Not advertised as primary contract | Not advertised | HTTP stream/body/part limits |
| Reproducible security matrix/corpus/mutation evidence | **60 + 20 matrix, 10-file corpus, 40k target mutations** | 45 general tests stated | General tests | HTTP-oriented tests/benchmarks |
| Automatic attachment extraction/write | **Never** | Metadata/extraction workflow | MIME AST | Sink-oriented upload delivery |

The overlap is real at the syntax layer: all three email projects parse some RFC
5322/MIME structure. MoonMIME's independent deliverable is the evidence and
policy layer before interpretation: ordered duplicates, immutable raw bytes,
source ranges, ambiguity findings, deterministic reports, and independently
bounded resource accounting. It deliberately excludes the convenience features
that define the other two email projects.

## MoonMailKit 12314

[`fhh12341/mailkit_12314`](https://mooncakes.io/docs/fhh12341/mailkit_12314@0.1.0)
describes a practical email/MIME analysis toolkit. Its public README includes
address parsing, normalized subjects, body/attachment extraction,
Authentication-Results, Received paths, DSN, mbox/archive helpers,
classification, privacy findings, security scoring, and policy checks.

MoonMIME does not reproduce those workflows or claim a better classifier. It
provides a lower-level byte-evidence model and parser-differential audit result
that such a workflow could consume before choosing one content view.

## mbt-email

[`Mr-Houjie/mbt-email`](https://mooncakes.io/docs/Mr-Houjie/mbt-email@0.1.0)
describes a pure MoonBit RFC 5322/2045 address and MIME parser whose key contract
is parsing raw text into an AST and serializing standards-compliant text.

MoonMIME intentionally does not construct or serialize mail and does not offer
address semantics. Reserialization is unsuitable as its forensic contract:
MoonMIME retains the original `Bytes` and points every finding back into that
immutable evidence.

## MoonPart

[`eisem/moonpart`](https://mooncakes.io/docs/eisem/moonpart@0.1.0) is a streaming-oriented parser and encoder for HTTP `multipart/form-data` (RFC 7578). Its published description explicitly states that it is not a general recursive MIME message parser and does not decode content-transfer encodings.

MoonMIME therefore does not compete for MoonPart's HTTP upload role. MoonMIME owns complete Internet Message inspection, recursive MIME entities, `message/rfc822`, ambiguity evidence, and `.eml` protocol testing. MoonMIME v0.2 does not provide multipart/form-data encoding, upload sinks, or streaming file delivery.

## Web-framework multipart helpers

MoonBit web frameworks expose upload-specific multipart helpers tied to HTTP request contexts and file/form collection. Those APIs solve request handling rather than byte-preserving recursive mail parsing. MoonMIME intentionally has no HTTP context, server, request, upload spill, or trusted storage abstraction.

## Local project portfolio

Before implementation, the workspace was checked against MoonBDD, MoonHttpCache, MoonIPFIX, MoonLab, MoonOCL/MoonOCI, and MoonExternalSort. Their domains are decision diagrams, HTTP caching, flow telemetry, deterministic distributed simulation, OCI layouts, and external sorting. MoonMIME does not reuse their product domain or primary interfaces.

## Recheck before submission

Because mooncakes.io changes continuously, repeat package-keyword and functionality searches immediately before resubmission. If another ambiguity/forensics package appears, update this table and narrow MoonMIME's claim instead of asserting uniqueness.
