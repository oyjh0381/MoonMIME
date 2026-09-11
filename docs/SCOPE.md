# MoonMIME v0.2 Scope

## Included

- Complete in-memory `.eml`-style messages supplied as `Bytes`.
- RFC 5322-style header block separation, unfolding, ordered duplicates, and source ranges.
- `Content-Type`, `Content-Disposition`, and `Content-Transfer-Encoding` semantics.
- Recursive `multipart/*` delimiter parsing with preamble and epilogue preservation.
- Direct, unencoded `message/rfc822` recursion.
- Bounded Base64 and Quoted-Printable decoding.
- RFC 2047 `B` and `Q` encoded-words.
- RFC 2231 extended values and numbered continuations for UTF-8, US-ASCII, and ISO-8859-1.
- Strict and compatible modes with stable errors and diagnostics.
- Read-only attachment enumeration, preferred text selection, and deterministic reports.
- Cross-target core packages plus a Native reference CLI.
- Ambiguity and unsafe-extraction audit findings with stable JSON and threshold exit policy.
- Reproducible synthetic security corpus, mutation stress, and multipart scan benchmark.

## Excluded from v0.2

- SMTP, IMAP, POP3, delivery, mailbox storage, and network fetching.
- Streaming input or multi-GiB message parsing.
- General MIME serialization or message mutation.
- S/MIME, OpenPGP, DKIM, ARC, SPF, or authenticity decisions.
- Antivirus, content disarm, HTML sanitization, and safe rendering.
- Automatic attachment extraction or trusting sender-provided paths.
- Arbitrary character-set conversion beyond UTF-8, US-ASCII, and ISO-8859-1.
- Structural recursion into transfer-encoded `message/rfc822` bodies.
- Recovery that invents bytes for corrupt Base64, Quoted-Printable, or boundaries.

## Compatibility contract

Compatible mode may accept bare LF/CR in header sections, selected parameter damage, duplicate singleton fields, unknown transfer-encoding labels, unpadded Base64 tails, bare-LF Quoted-Printable soft breaks, and a missing final multipart delimiter. Every accepted structural deviation produces a diagnostic where the relevant layer has source-location context.

Compatible does not mean permissive at all costs. Resource limits and byte-range invariants always remain mandatory.
