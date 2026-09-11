# Runnable integration cases

These fixtures drive two complete upper-layer workflows rather than isolated
parser calls. They contain no real mail or personal data.

## 1. Mail gateway pre-ingestion gate

```text
moon run --target native cmd/moonmime-gateway -- examples/integrations/gateway-clean.eml
moon run --target native cmd/moonmime-gateway -- examples/integrations/gateway-ambiguous.eml
```

The first command emits an `allow` JSONL record and exits 0. The second emits a
`quarantine` record with three evidence-backed reason codes and exits 3. A mail
gateway can stream the record into its queue metadata without decoding or
writing the attachment.

## 2. Forensic evidence sidecar

```text
moon run --target native cmd/moonmime-forensics -- CASE-2026-0042 examples/integrations/forensic-case.eml
```

The command emits `moonmime.forensics.v1` JSON with the whole-message SHA-256,
source identity, message metadata, attachment entity path, exact encoded body
range, attachment-region SHA-256, and the MoonMIME audit report. It never
modifies the evidence file or extracts its body.

Run `scripts/verify-integrations.sh` or `scripts/verify-integrations.ps1` to
assert all decisions and hashes end to end.
