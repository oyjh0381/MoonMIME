# Security Model

MoonMIME is designed to parse untrusted message bytes without granting those bytes filesystem or network authority.

## Defenses

- Validated input, header, line, field, parameter, boundary, depth, entity, body, decoded-output, and diagnostic limits.
- Exact line-anchored boundary matching prevents prefix and mid-line false positives.
- Canonical Base64 tail-bit and padding validation.
- Explicit handling of damaged Quoted-Printable escapes.
- Structured strict/compatible behavior instead of silent repair.
- Attachment filenames remain metadata; the CLI never writes them.
- Parser core performs no I/O, subprocess execution, HTML rendering, or network access.
- Audit findings retain entity paths and source ranges, allowing exact evidence review.
- `--fail-on` supports quarantine policy without treating a score as a probability.

## Caller responsibilities

- Treat filenames as untrusted labels. If a future application extracts content, generate its own storage name and enforce a confined destination.
- Do not render HTML without an independent sanitizer and isolation policy.
- Scan decoded attachments with an appropriate security product before use.
- Do not infer sender authenticity from headers parsed by this library.
- Select limits appropriate to the deployment and enforce an outer request timeout.
- Avoid logging confidential message bodies or decoded attachment data.

## Known limits

The v0.2 parser is in-memory. Its limits prevent individual oversized inputs but do not implement process-wide admission control. Compatible mode accepts selected non-standard syntax and therefore should not be used when canonical conformance is a security requirement. Audit rules are structural heuristics: a finding does not prove maliciousness and an empty report does not prove safety.

Report vulnerabilities privately to the repository owner after the public repository is available. Do not attach real confidential mail to a public issue; construct a minimal synthetic reproducer.
