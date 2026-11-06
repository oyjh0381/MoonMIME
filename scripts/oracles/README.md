# Independent MIME observations

Two development-only references are executed, not emulated:

- CPython 3.11.8 `email.parser.BytesParser` with `email.policy.default` — full
  MIME tree, declared media/name and decoded leaf SHA-256. License: PSF-2.0.
  [Official parser docs](https://docs.python.org/3/library/email.parser.html).
- Nodemailer MailParser 3.14.2 — ordered attachment metadata and payload SHA-256,
  using `simpleParser` with HTML/text conversion and image links disabled.
  License: MIT. [Upstream](https://github.com/nodemailer/mailparser).

`package-lock.json` pins transitive dependencies and integrity hashes. The npm
mirror was needed for this machine's TLS connectivity; it does not alter the
locked versions/integrities. Dependencies run with install scripts disabled.
No reference library implementation is copied into the MoonBit runtime or
redistributed as a vendored source tree.

```sh
npm ci --prefix scripts/oracles --ignore-scripts --no-audit --no-fund
moon build --target native --release --deny-warn
python scripts/differential.py --binary PATH_TO_BUILT_MOONMIME_EVIDENCE
```

The 32 byte fixtures are generated deterministically by `corpus()` in
`scripts/differential.py`; they are original Apache-2.0 synthetic inputs, not
private mail, copied upstream tests, or samples from the research papers.
Each report binds the input with its SHA-256. Coverage includes empty/all-octet
Base64, folded encoding, QP, identity encodings, folded headers, RFC 2231,
nested multipart, preamble/epilogue and a plain body.

For 24 normal cases, exact tree/path/media/filename/decoded hashes must agree
with Python, and the same attachment abstraction must agree with MailParser.
Every MoonMIME encoded-region fingerprint is independently checked against
Python `hashlib` on the original range. MailParser intentionally offers a
flattened attachment view; its view is not compared as if it exposed the full
MIME tree. This is a bounded interoperability corpus, not a standards suite.

Eight boundary cases require exact reviewed observation signatures with written
rationales in `reviewed-differences.json`. Four have differing observations:
invalid Base64 alphabet, malformed QP, unknown transfer encoding and encoded
embedded message scope. Four agree on content while making recovery visible:
unpadded Base64, duplicate Content-Type, bare LF and missing closing boundary.
Signatures cover reference views, MoonMIME views, decode statuses, completeness
and diagnostics; changing a result fails the gate. Review the generated report
before manually editing a baseline. There is no automatic baseline acceptance.

Reference agreement is not proof of correctness. A discrepancy is not proof of
an exploitable vulnerability. Fix protocol defects when evidence supports that
conclusion; otherwise retain an explicit policy or scope explanation. The
current results establish 24 agreements and 8 reviewed observations, not a
32/32 identical-parser claim or a security detection rate.
