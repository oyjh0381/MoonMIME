# MoonMIME 0.3.0 pre-release checklist

- [x] Preserve the rejected-submission baseline in local-only `.private/`.
- [x] Add two representative upper-layer integrations with public APIs and Native reference CLIs.
- [x] Add protocol-exact synthetic fixtures and deterministic expected outputs.
- [x] Verify gateway allow/quarantine actions, exit codes, and three evidence codes end to end.
- [x] Verify forensic whole-message and attachment-region SHA-256 bindings end to end.
- [x] Run 167 tests on Wasm, Wasm-GC, JavaScript, and Native with `--deny-warn`.
- [x] Run all-target check/build, formatting, interface generation, corpus, and integration gates.
- [x] Confirm more than 4,000 effective MoonBit lines and more than 15 meaningful commits.
- [x] Confirm the application and `.private/` are absent from Git history and the Mooncakes archive.
- [ ] Push the exact 0.3.0 commit and verify all GitHub Actions jobs.
- [ ] Publish `oyjh0381/moonmime@0.3.0` and verify a clean consumer installation.
- [ ] Synchronize the Gitlink repository and update the competition form before 2026-09-24.

The final publication and competition-form steps are external release actions;
their result must be checked rather than assumed by the source tree.
