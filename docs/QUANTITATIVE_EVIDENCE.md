# MoonMIME quantitative evidence

Measurement date: 2026-09-11. Baseline commit for the benchmark executable:
`cac6b54f1cbbad90b60e3b006e650219310f89a9`.

## Security scenario matrix

`audit/security_matrix_test.mbt` exercises 60 labelled suspicious variants:
10 conflicting `Content-Type` values, 10 conflicting identity/MIME singleton
fields, 10 path-bearing filenames, 10 executable filename suffixes, 10 bare-LF
messages, and 10 opaque encoded `message/rfc822` bodies. It also contains 20
ordinary-message controls. The result is 60/60 expected findings and 20/20
finding-free controls.

`security-corpus/` adds six reviewable adversarial `.eml` files and four benign
controls. `bash scripts/evaluate-security-corpus.sh` or
`powershell -File scripts/evaluate-security-corpus.ps1` reports:

```text
MoonMIME synthetic corpus: TP=6 TN=4 FP=0 FN=0
```

These are repository-authored protocol patterns, not a representative-mail or
malware detection rate. Each payload is inert and uses reserved `.test` domains.

## Mutation robustness

`audit/mutation_test.mbt` applies 10,000 deterministic one-byte mutations to a
valid message and requires every input to return either a parsed result or a
structured `MimeError`, never a panic or hang. Running the test on `wasm`,
`wasm-gc`, `js`, and `native` executes 40,000 mutation cases in total. On the
measurement baseline all four targets passed with zero panic or hang.

## Native multipart scan throughput

Command: `moon run --target native --release cmd/moonmime-bench`. Each row scans
approximately 125–128 MiB in-process, excluding file I/O and process startup.
Seven batches were run per input size; p95 is the slowest batch of seven (a
deliberately conservative small-sample statistic).

Environment: Windows 10.0.19045, 16 logical processors, Intel64 Family 6 Model
165 Stepping 5; Moon `0.1.20260827`; moonc `0.10.11+6ff76a5f9`.

| Input | Iterations/batch | median batch | p95 batch | median throughput | median/input |
|---:|---:|---:|---:|---:|---:|
| 64 KiB | 2,000 | 123 ms | 136 ms | 1,016.3 MiB/s | 0.0615 ms |
| 256 KiB | 500 | 99 ms | 105 ms | 1,262.6 MiB/s | 0.1980 ms |
| 1 MiB | 128 | 93 ms | 104 ms | 1,376.3 MiB/s | 0.7266 ms |
| 4 MiB | 32 | 92 ms | 99 ms | 1,391.3 MiB/s | 2.8750 ms |

For successive 4× input increases, median per-message time grew by 3.22×,
3.67×, and 3.96×. This supports near-linear boundary scanning on this synthetic
shape; it is not a universal complexity proof and does not measure decoding.

## Reproduction gates

```text
moon test audit --target all --deny-warn
bash scripts/evaluate-security-corpus.sh
moon run --target native --release cmd/moonmime-bench
```

External research numbers and their primary sources are intentionally separated
from these project measurements in `SECURITY_FORENSICS_EVIDENCE.md`.
