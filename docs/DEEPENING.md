# Evidence inventories, verification and gateway policy

These APIs are introduced in 0.4.0. Use root `moon.work` to run the independent
consumer against the source checkout.

## Four reusable capabilities

| Package/API | Output and intended integration | Boundary |
| --- | --- | --- |
| `evidence.observe` | Every entity's path, declared media/name, original body range and SHA-256; decoded leaf size/hash under a shared budget | No attachment extraction, content sniffing, charset conversion or malware verdict |
| `forensics.verify_manifest` / `verify_sidecar` | Recomputed byte/metadata/range/audit comparison; canonical serialized sidecar check | Integrity consistency, not authenticated acquisition or a signature |
| `gateway.evaluate_with_rules` | Caller allowlist/blocklist, case-insensitive filename suffix, count/single/total wire quotas, required names and parser-recovery policy | Rules apply to declared leaf attachment candidates, not all possible hidden content |
| `gateway.evaluate_batch` | Ordered allow/quarantine/reject rows, unique source labels, message and aggregate-input preflight | Caller supplies bytes; host enforces queue, memory isolation and final decisions |

The new schemas are `moonmime.inventory.v1`, `moonmime.verification.v1`,
`moonmime.policy.v1` and `moonmime.batch.v1`. Existing v1 schemas and APIs remain.

## Decode status is evidence

`decoded` means a supported leaf encoding produced bytes. `recovered` means
compatible decoding preserved/accepted a deviation. `unsupported` means an
unknown encoding has no claimed decoded payload. `unavailable` records a decode
failure or exhausted output budget. `container` has children rather than a leaf
payload. `opaque` marks a nonempty encoded embedded message that cannot be
expanded while preserving original source coordinates.

`complete` is false for unavailable/unsupported/opaque payloads. A true value
does not mean strict validity, absence of diagnostics, complete semantic MIME
support, or safety. Inspect diagnostics, per-entity status and audit separately.
No decoded payload bytes are retained in the inventory; callers can use hashes
for content-addressed lookup or duplicate comparison without writing filenames.

Default input/leaf/decode limits come from `ResourceLimits::secure_defaults`.
Inventory uses one `DecodeBudget` for all leaves. A failed decode is not charged;
later leaves may still be observed. Encoded-region hashes remain available even
when decoded content is unavailable. QP literal control/high bytes preserved in
compatible mode now set the recovery flag, rather than appearing canonical.

## Forensic verification

`verify_manifest` checks the raw byte count and SHA-256 first, then reparses the
source and compares message metadata, attachment count/path/range/name/type/hash
and audit output. Untrusted manifest ranges never drive source slicing.

`verify_sidecar` accepts exactly `forensics.render_json` output with optionally
one final LF/CRLF. Alternative whitespace, keys or formatting are rejected, even
when another JSON reader could consider them equivalent. This is a deliberately
narrow canonical v1 verifier, not a general JSON deserializer. Case and source
labels are supplied by the caller. A changed label fails this comparison but
an attacker who can replace both source and manifest can recompute hashes;
trusted storage/signatures remain the integrating application's responsibility.

New Native adapter:

```sh
moon run cmd/moonmime-evidence --target native -- inventory examples/sample.eml --compatible
moon run cmd/moonmime-evidence --target native -- capture examples/sample.eml CASE SOURCE
# Save capture stdout as UTF-8 without a BOM, then:
moon run cmd/moonmime-evidence --target native -- verify examples/sample.eml manifest.json CASE SOURCE
```

Exit 0 means successful operation, 3 means verification mismatch, 2 means usage,
read or parsing failure. Inventory decoding failures are represented in JSON
with `complete=false`, not an exit-code safety decision. The new adapter opens
seekable files read-only, checks size before allocation, reads at most observed
size+1 (bounded by 32 MiB for mail, 16 MiB for sidecars), closes on every path,
and rejects size changes. It is not a streaming parser and cannot detect a
same-size concurrent rewrite; preserve source files before acquisition.
Legacy CLI adapters still read a whole file before parser limits apply.

## Gateway rules and batch integration

Import `oyjh0381/moonmime/integrations/gateway` as `@gateway`:

```moonbit nocheck
let rules = {
  ..@gateway.GatewayRules::default(),
  blocked_media_types: ["application/pdf"],
  blocked_filename_suffixes: [".exe", ".ps1"],
  max_attachments: 8,
  require_attachment_names: true,
}
let batch = @gateway.evaluate_batch(inputs, rules,
  max_messages=128, max_total_input_bytes=16777216L)
println(@gateway.batch_json(batch))
```

Media rules are exact lowercase `type/subtype`, without wildcard matching.
Allowlist `None` disables it; `Some([])` allows no declared attachment types.
Required names reject missing, empty and whitespace-only values. Even a present
name is metadata, not a safe filesystem path. Wire sizes count encoded
body regions, not decoded output; use `evidence` for decoded availability.
Custom rules only add quarantine reasons; existing audit findings are retained.
Batch configuration or preflight errors raise before any row is returned.
Malformed individual messages are explicit reject rows and do not discard
successful neighbors. Source order is preserved; duplicate/empty/oversized IDs
are refused. Aggregate input quotas are not a bound on total process heap or
serialized output size. Avoid increasing quotas without host-level isolation.

## Three representative uses

1. **Mail-ingestion policy**: routing systems can share one typed rule policy,
   distinguish custom restrictions from audit evidence, and preserve reject rows
   in a batch instead of aborting the entire ingestion operation.
2. **Evidence storage and deduplication**: preserve `.eml`, attach source-bound
   manifests, compare encoded and decoded fingerprints, and recheck the source
   before review. Different Base64 formatting can share a decoded hash while
   retaining distinct original evidence.
3. **Parser integration regression**: SDKs and mail-processing services can
   compare tree and payload interpretations against CPython and MailParser,
   fail new unreviewed differences, and retain reviewed policy deviations.

`consumers/mailroom` runs these public APIs as a separate module. It proves an
integration is executable; it does not establish external adoption.

## Algorithm and resource costs

Let `n` be input bytes, `d` nesting depth, `e` entities, `b` total decoded bytes
and `r` configured rules. Parsing and hashing every enclosing region cost
`O(n*d + b)` time for inventory; policy evaluation adds `O(e*(r+d))` including
entity-path lookup. Defaults bound `d=16`, `e=1000`, rule lists at 64 entries.
Live structural storage is `O(n + e*d)` plus transient body/hash/decoded buffers;
the decoded budget bounds payload output, not peak resident memory.

Sidecar verification rebuilds once and reuses the result. The former valid-path
double rebuild was removed, reducing constant cost without changing asymptotic
complexity. Streaming hashes and lazy tree views could reduce copying, but would
add API/state complexity; the current bounded in-memory design preserves exact
source coordinates and remains appropriate for the stated message limits.
