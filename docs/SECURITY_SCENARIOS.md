# Security, forensics, and protocol-test scenarios

MoonMIME is a pre-interpretation component. It does not replace antivirus,
authentication, or a mail client; it supplies deterministic structure evidence
before those systems make decisions.

## 1. Mail-ingestion ambiguity gate

A webhook or archive importer receives an untrusted `.eml`, parses in compatible
mode, and runs `audit_message`. Conflicting `Content-Type`, transfer encoding, or
identity singleton fields become high-severity findings with exact byte ranges.
The caller can quarantine on `high`, while still retaining the original bytes.

```text
moon run --target native cmd/moonmime -- audit message.eml --compatible --json --fail-on high
```

Exit code `3` means the configured finding threshold was reached. No attachment
is decoded or written by this operation.

## 2. Forensic evidence sidecar

An incident-response tool stores the original `.eml` as immutable evidence and
stores `moonmime.forensics.v1` beside it as derived metadata. The implemented
adapter binds the whole message and every attachment's original encoded body
range with SHA-256. Every finding retains an entity path and half-open source
byte range. The caller remains responsible for acquisition records, evidence
custody, storage, timestamps, and signatures.

Both the mail gate and forensic sidecar are executable, CI-verified cases. See
[INTEGRATION_CASES.md](INTEGRATION_CASES.md) for commands and fixed outputs.

## 3. Parser differential oracle

A protocol test harness feeds the same synthetic or licensed corpus to multiple
parsers and normalizes their entity/attachment views. MoonMIME contributes the
ordered duplicate headers, entity paths, body ranges, compatibility diagnostics,
and stable JSON needed to explain a disagreement. Strict mode provides a reject
oracle for malformed MIME; compatible mode shows which recovery occurred.

## Decision boundary

MoonMIME flags ambiguity primitives and unsafe extraction metadata. It does not
claim that a finding proves malicious intent, that no finding proves safety, or
that its risk score is a probability. Policy belongs to the integrating system.
