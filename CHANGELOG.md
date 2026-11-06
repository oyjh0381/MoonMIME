# Changelog

## 0.4.0 - Unreleased

- Add a portable encoded/decoded entity fingerprint inventory with shared output budget and explicit unavailable/unsupported/opaque states.
- Recompute typed forensic manifests and verify canonical v1 sidecars; untrusted ranges never drive slicing.
- Add caller-owned media/name/size/recovery rules and ordered batch decisions with aggregate input preflight.
- Add a bounded-read Native evidence CLI, a separate public-API consumer and a reproducible integrity/tampering demo.
- Add two independent development-only MIME references, 32 original fixtures and exact reviewed boundary-observation baselines.
- Add full-CLI timing/process-memory probes and document their measurement limits.
- Migrate explicit trait extensions and qualified blackbox calls for MoonBit 0.10.16; remove compiler warning suppressions from CI.
- Make compatible QP literal control/high-byte preservation visible in the transfer recovery flag.

## 0.3.1 - 2026-10-01

- Reject raw control/high bytes and bare line endings in strict Quoted-Printable body decoding; keep compatible-mode inspection behavior.
- Add regression coverage and moonc 0.10.14 CI compatibility flags.

## 0.3.0 - 2026-09-11

- Add a reusable mail-gateway policy adapter and batch JSONL CLI with deterministic allow/quarantine/reject decisions.
- Add a forensic evidence-manifest adapter with whole-message and encoded attachment-region SHA-256 bindings.
- Add portable SHA-256 verified against three standard test vectors.
- Add three protocol-exact integration fixtures and cross-platform end-to-end verification scripts.
- Document two representative upper-layer workflows, measured outputs, operational boundaries, and reproduction commands.

## 0.2.0 - 2026-09-11

- Add `audit` API and CLI for parser ambiguity and unsafe extraction metadata.
- Add stable `moonmime.audit.v1` JSON with severity, entity paths, and byte ranges.
- Add 60 suspicious scenario variants, 20 benign controls, and 40,000 cross-target deterministic mutation executions.
- Add a reviewable 10-message synthetic corpus and reproducible evaluator.
- Add a native multipart throughput probe and measured quantitative evidence.
- Document real security, forensic, and protocol-testing integrations and primary-source evidence.

## 0.1.0 - 2026-09-10

- Add byte-preserving recursive MIME entity parsing.
- Add strict and compatible parsing with resource limits and diagnostics.
- Add Base64, Quoted-Printable, RFC 2047, and RFC 2231 decoding.
- Add attachment, subject, and preferred-text queries.
- Add deterministic JSON/text reports and Native inspection CLI.
- Add synthetic examples, cross-target checks, documentation, and CI configuration.

Published as `oyjh0381/moonmime@0.1.0`.
