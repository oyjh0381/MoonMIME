# Mailroom consumer integration

This is a separate MoonBit module (`moonmime_examples/mailroom`), maintained in
this repository as reproducible integration evidence. It imports only the
public API paths of MoonMIME. It is not an external adoption claim.
Root `moon.work` resolves the new, unpublished 0.4.0 library locally.

From the repository root, with MoonBit 0.10.16:

```sh
moon run consumers/mailroom --target wasm-gc --deny-warn
moon run consumers/mailroom --target native --deny-warn
```

The consumer acts as a small pre-ingestion application: it routes a benign
message, a caller-blocked PDF declaration and a malformed input into exactly
one allow/quarantine/reject row each. It then verifies a known decoded payload
hash, captures a forensic sidecar, accepts the original and refuses a changed
source label. All assertions use public APIs. No HTTP server, queue, attachment
extraction, antivirus or third-party user is implied.

To use it in a separate repository after a future 0.4.0 publication, copy this
directory and use the dependency declared in its own `moon.mod`. For local
development, `moon.work` is required; the registry still serves earlier releases.
