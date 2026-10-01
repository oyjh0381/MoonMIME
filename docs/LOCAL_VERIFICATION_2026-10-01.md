# Release verification — 2026-10-01

This records verification of `oyjh0381/moonmime@0.3.1`. It is not a claim of
final acceptance by the contest organizers.

- Toolchain: `moonc 0.10.14+7d59c7ec9`, `moon 0.1.20260920`.
- Change: Strict Quoted-Printable rejects bare line endings and raw control/high bytes; compatible mode still permits inspection.
- `moon fmt --check`, all-target strict check, and all-target strict build: passed.
- All-target tests: 168 passed per listed backend; zero failed.
- Native runnable example: `moon run --target native cmd/moonmime -- inspect examples/sample.eml --compatible --json` passed.
- Effective local MoonBit lines: 6100, counting nonblank, non-`//` lines in
  checked-in `.mbt` files including tests and examples, excluding generated
  build artifacts and downloaded dependencies.
- License: Apache-2.0; existing README, CI workflow, examples, and tests remain
  part of the repository.
- Release commit: `3a1292cc4309c40ac9cfae37244ac22ba5a07d74`, pushed to
  the public GitHub repository's `main` branch.
- [GitHub Actions run 36820584924](https://github.com/oyjh0381/MoonMIME/actions/runs/36820584924)
  passed all five jobs: documentation, portable checks on Ubuntu and Windows,
  and native CLI/test/build checks on Ubuntu and Windows.
- Local synthetic security corpus reported `TP=6 TN=4 FP=0 FN=0`; integration
  verification checked gateway allow/quarantine and forensic SHA-256 evidence.
- The `oyjh0381-moonmime-0.3.1.zip` archive was 130,161 bytes with SHA-256
  `f22a5340f33927e4f1871c1563769130da2add7ae80c8ce2481f7750d1b9be89`.
  The archive and tracked files contain no `.private/`, application document,
  dependency cache, build directory, or credentials.
- `moon publish` returned `200 OK`; a subsequent `moon search moonmime --json`
  reported `0.3.1` as the current version.
- An isolated consumer module updated the registry, installed exactly
  `oyjh0381/moonmime@0.3.1`, and passed the public strict/compatible
  Quoted-Printable API test on Wasm, Wasm-GC, JavaScript, and Native.

For moonc 0.10.14, strict check/build/test use
`--deny-warn --warn-list=-implicit_impl_as_method-test_unqualified_package`. The warning list exempts only the compiler's
`implicit_impl_as_method` and `test_unqualified_package` migration warnings;
all other warnings remain fatal. Migrating those call sites and derived-method
exposure is future maintenance, not a completed fix.

Reproduction from the repository root:

```sh
moon fmt --check
moon check --target all --deny-warn --warn-list=-implicit_impl_as_method-test_unqualified_package
moon build --target all --deny-warn --warn-list=-implicit_impl_as_method-test_unqualified_package
moon test --target all --deny-warn --warn-list=-implicit_impl_as_method-test_unqualified_package
moon run --target native cmd/moonmime -- inspect examples/sample.eml --compatible --json
```

The package release, public repository, remote CI, and independent consumer
have been verified. Final contest acceptance remains the organizers' decision.
