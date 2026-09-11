# Testing

## Local strict gates

Run from the repository root:

```text
moon version --all
moon fmt --check
moon check --target all --deny-warn
moon test --target all --deny-warn
moon build --target all
moon info
git diff --check
```

Native CLI smoke test:

```text
moon run --target native cmd/moonmime -- inspect examples/sample.eml --compatible
moon run --target native cmd/moonmime -- text examples/sample.eml --compatible
moon run --target native cmd/moonmime -- attachments examples/sample.eml --compatible
moon run --target native cmd/moonmime -- audit security-corpus/attack_conflicting_content_type.eml --compatible --json
bash scripts/evaluate-security-corpus.sh
powershell -File scripts/evaluate-security-corpus.ps1
bash scripts/verify-integrations.sh
powershell -File scripts/verify-integrations.ps1
moon run --target native --release cmd/moonmime-bench
```

## Coverage categories

- Normal: plain, Base64, Quoted-Printable, nested multipart, embedded message, Unicode filename.
- Boundary: empty ranges, exact output caps, header and boundary length caps, depth/entity caps.
- Invalid: broken headers, duplicate singletons, invalid Base64/QP, unknown charset/encoding, malformed RFC 2231 and RFC 2047 forms.
- Compatibility: bare LF, unpadded Base64, bare-LF soft break, unresolved extension values, missing closing boundary.
- Adversarial: boundary prefixes, mid-line markers, closing-delimiter suffixes, non-zero Base64 tail bits, range violations.
- Reporting: deterministic schema, JSON escaping, paths, stats, filenames, and diagnostics.
- Security matrix: 60 suspicious variants across six classes and 20 benign controls.
- Corpus: six reviewable attack patterns and four benign `.eml` controls.
- Robustness: 10,000 deterministic mutations per target, with structured error or success required.
- Performance: in-process multipart boundary scanning at four input sizes.
- Upper-layer integrations: fixed gateway actions/exit codes/finding codes and forensic schemas/ranges/SHA-256 bindings.
- Cryptographic primitive: SHA-256 empty, short, and multi-block standard vectors on every target.

The CI matrix runs Ubuntu and Windows checks. Publication acceptance additionally requires a clean worktree, current generated interfaces, more than 4,000 effective MoonBit lines, and more than 15 meaningful commits.
