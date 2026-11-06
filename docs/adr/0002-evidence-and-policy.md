# Keep observation, verification and caller policy separate

The inventory reports raw source ranges and separate encoded/decoded SHA-256
values. It never labels an unknown transfer encoding as successfully decoded.
Every leaf shares one decoded-output budget; a failure leaves a visible status
and the original fingerprint. Encoded embedded messages remain opaque because
expanded bytes cannot honestly index the original source tree. `complete`
describes represented payload availability, not MIME validity or safety.

Forensic verification reparses the original bytes and recomputes metadata and
hashes. Typed manifests are compared semantically. Serialized sidecars must be
the exact canonical v1 output (one terminal newline allowed); this deliberately
avoids an ambiguous second JSON interpretation with duplicate/unknown keys.
It rejects harmless reformatting too. Neither operation authenticates case
identity or acquisition, and neither substitutes for a digital signature.

Gateway rules are caller policy over declared attachment metadata, distinct
from built-in audit findings. They can add quarantine reasons but cannot erase
audit evidence. Batch preflight validates unique IDs and aggregate quotas;
individual malformed messages produce explicit reject records. Hosts retain
responsibility for memory isolation, scheduling, storage and enforcement.

Independent parser observations compare equal abstraction levels: CPython's
tree and MailParser's attachment view. Normal fixtures require agreement;
malformed/scope fixtures require a reviewed exact signature and rationale.
An observed difference is not automatically a defect or a vulnerability.
