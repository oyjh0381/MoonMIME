# Related Work and Ecosystem Boundary

Research snapshot: 2026-09-08. This comparison is evidence for project positioning, not a claim that no unpublished or newly released project can overlap.

## MoonPart

[`eisem/moonpart`](https://mooncakes.io/docs/eisem/moonpart@0.1.0) is a streaming-oriented parser and encoder for HTTP `multipart/form-data` (RFC 7578). Its published description explicitly states that it is not a general recursive MIME message parser and does not decode content-transfer encodings.

MoonMIME therefore does not compete for MoonPart's HTTP upload role. MoonMIME owns complete Internet Message parsing, recursive MIME entities, `message/rfc822`, RFC 2047, RFC 2231, Base64/Quoted-Printable payload decoding, raw source ranges, message queries, and `.eml` inspection. MoonMIME v0.1 does not provide multipart/form-data encoding, upload sinks, or streaming file delivery.

## Web-framework multipart helpers

MoonBit web frameworks expose upload-specific multipart helpers tied to HTTP request contexts and file/form collection. Those APIs solve request handling rather than byte-preserving recursive mail parsing. MoonMIME intentionally has no HTTP context, server, request, upload spill, or trusted storage abstraction.

## Local project portfolio

Before implementation, the workspace was checked against MoonBDD, MoonHttpCache, MoonIPFIX, MoonLab, MoonOCL/MoonOCI, and MoonExternalSort. Their domains are decision diagrams, HTTP caching, flow telemetry, deterministic distributed simulation, OCI layouts, and external sorting. MoonMIME does not reuse their product domain or primary interfaces.

## Recheck before publication

Because mooncakes.io changes continuously, repeat package-keyword and functionality searches immediately before publishing. If a general recursive MIME parser appears, document a feature-level comparison and narrow MoonMIME's claim instead of asserting uniqueness.
