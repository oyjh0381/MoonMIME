# Representative upper-layer integrations

MoonMIME 0.3.0 includes two runnable integrations that consume the public
parser/audit model as infrastructure. Both use synthetic fixtures committed as
protocol bytes and are exercised on Ubuntu and Windows CI.

## Case A: mail gateway pre-ingestion policy

**Operational problem.** A gateway must make one deterministic decision before
downstream filters, archive importers, and mail clients can disagree about an
ambiguous message. It must retain reasons suitable for queue metadata and must
not execute or extract untrusted content.

**Integration.** `integrations/gateway` turns a byte input, source identifier,
and explicit policy into `GatewayDecision`. The executable
`cmd/moonmime-gateway` accepts multiple files, emits one
`moonmime.gateway.v1` JSONL record per input, exits 0 when all inputs are
allowed, and exits 3 if any input is quarantined or rejected. The caller still
owns queue movement and business policy.

```text
moon run --target native cmd/moonmime-gateway -- examples/integrations/gateway-clean.eml
moon run --target native cmd/moonmime-gateway -- examples/integrations/gateway-ambiguous.eml
```

**Reproducible evidence.** The clean fixture yields `allow`, zero findings, and
exit 0. The ambiguous fixture yields `quarantine`, exit 3, and three causes:
`conflicting-singleton-header`, `unsafe-attachment-filename`, and
`executable-attachment-name`. The decision is made without body decoding or
attachment writes.

## Case B: forensic evidence manifest

**Operational problem.** An examiner needs a machine-readable sidecar that can
be checked against the original bytes and can point from a suspicious MIME part
back to its precise encoded region. A generic mail summary is insufficient for
that workflow.

**Integration.** `integrations/forensics` builds a deterministic
`moonmime.forensics.v1` manifest. It binds the original `.eml` with SHA-256,
records case/source identifiers and selected message metadata, then records each
attachment candidate's entity path, exact half-open body range, media type,
filename, and SHA-256 of the encoded source region. It embeds the complete audit
report and performs no evidence mutation or extraction.

```text
moon run --target native cmd/moonmime-forensics -- CASE-2026-0042 examples/integrations/forensic-case.eml
```

**Reproducible evidence.** The committed fixture produces one manifest, one
attachment record, two verified SHA-256 bindings, and zero audit findings. The
whole-message digest is
`c48092a02135fe2292ee2b2ac2d9b30a01f11b229153a1c813bcb66dd07d7f74`;
the attachment's encoded-region digest is
`fc513853d72701d4aa64a4f08f5c51b127e5823480c04eb5c90a306d938959c8`.
The portable SHA-256 implementation is tested against three standard vectors.

## Verification and limits

Run either cross-platform verifier:

```text
bash scripts/verify-integrations.sh
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/verify-integrations.ps1
```

The scripts assert exact actions, exit codes, finding codes, schemas, filenames,
and hashes; CI runs them on their native host shells. These cases demonstrate
composition and reuse, not a claim that MoonMIME is a complete mail gateway or
digital-forensics case-management system. Transport, queue/storage mutation,
acquisition time, examiner identity, signing, custody logs, and final policy
remain explicitly above this library boundary.
