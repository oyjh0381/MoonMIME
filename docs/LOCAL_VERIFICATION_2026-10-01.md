# Local verification — 2026-10-01

This records the current local-only delta; it is not a claim that this delta has
passed remote CI or been uploaded to GitHub or mooncakes.io.

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

Before contest acceptance, the owner must authorize/upload this delta, verify
public GitHub access and the actual remote CI run, then publish or update the
mooncakes.io package as applicable. Existing release records are historical.
