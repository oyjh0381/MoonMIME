# Reproducible 3–5 minute walkthrough

Prerequisites: MoonBit **0.10.16+b1a0e846e**, CPython **3.11.8**, Node
**24.19.0** and npm. Oracles are development tools only. First install their
locked dependencies with scripts disabled:

```sh
npm ci --prefix scripts/oracles --ignore-scripts --no-audit --no-fund
python scripts/validate.py
```

On Windows installations affected by Moon's extended-path compiler issue, use
the existing path-normalization wrapper through
`python scripts/validate.py --moon-wrapper ABSOLUTE_PATH_TO_MOON_PS1`.
The wrapper changes child executable paths only; it must not change compilers.
Ordinary Windows toolchain installations can run without it.

Suggested presentation, with outputs produced by these commands:

| Time | Show | Verifiable outcome |
| --- | --- | --- |
| 0:00–0:45 | `consumers/mailroom` and its own `moon.mod` | Independent module imports public packages; no internal access |
| 0:45–1:30 | Batch JSON output | Exactly one allow, one caller-policy quarantine and one parse rejection |
| 1:30–2:15 | Inventory JSON | Encoded source hash differs from decoded `hello` hash; source ranges retained |
| 2:15–3:00 | `scripts/demo.py` output | Original unchanged; changed source/label refused; oversized file refused |
| 3:00–4:00 | Differential report | 24 normal agreements, 8 reviewed boundary observations; no unreviewed change |
| 4:00–5:00 | Resource probe | Full CLI startup/I/O/decoding/hash/JSON cost at four sizes, with process memory |

The Python runner builds Release, executes the consumer on Wasm-GC and Native,
then runs the evidence demo, independent oracles and resource probe. Each stage
checks results and fails on an unexpected outcome. Generated inputs and reports
stay in `.private/`, ignored by Git and Mooncakes. `--skip-resources` omits the
machine-dependent timing probe for CI. There is no video or external-user claim.

See [oracle methodology](../scripts/oracles/README.md) for the exact comparison
and [capability guide](DEEPENING.md) for limits. Timing includes process startup
and filesystem I/O; do not compare it with the older in-process parser-only
benchmark. Memory is OS PeakWorkingSetSize on Windows, sampled `/proc` VmHWM
(a lower bound) on Linux. Five rounds establish a local observation only, not
a throughput/SLA guarantee. No timing threshold is used as a correctness gate.
