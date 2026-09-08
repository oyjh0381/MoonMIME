# Release Checklist

- [ ] Re-run mooncakes.io overlap search and update `docs/RELATED_WORK.md` date.
- [ ] Confirm `moon.mod` version, repository URL, license, keywords, and README.
- [ ] Run `moon version --all` and record the toolchain.
- [ ] Run formatting, all-target check/test/build, API generation, and CLI smoke tests.
- [ ] Confirm effective MoonBit source exceeds 4,000 lines without generated code.
- [ ] Confirm more than 15 meaningful commits and a clean worktree.
- [ ] Review resource-limit, malformed-input, and path-safety tests.
- [ ] Confirm all fixtures are synthetic and third-party licenses are recorded.
- [ ] Push to the owner-approved public GitHub repository.
- [ ] Verify GitHub Actions on the pushed commit.
- [ ] Create the required Gitlink repository and replace the proposal placeholder.
- [ ] Publish `oyjh0381/moonmime@0.1.0` to mooncakes.io only after approval.
- [ ] Verify the public Mooncakes README, API docs, license, example, and install command.
- [ ] Tag `v0.1.0` and update `CHANGELOG.md` from Unreleased to the release date.
