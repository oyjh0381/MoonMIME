# Changelog

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
