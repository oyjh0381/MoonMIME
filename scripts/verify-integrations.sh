#!/usr/bin/env bash
set -euo pipefail

clean="$(moon run --target native cmd/moonmime-gateway -- examples/integrations/gateway-clean.eml)"
grep -Fq '"action":"allow"' <<<"$clean"

set +e
blocked="$(moon run --target native cmd/moonmime-gateway -- examples/integrations/gateway-ambiguous.eml)"
blocked_status=$?
set -e
test "$blocked_status" -eq 3
grep -Fq '"action":"quarantine"' <<<"$blocked"
grep -Fq 'conflicting-singleton-header' <<<"$blocked"
grep -Fq 'unsafe-attachment-filename' <<<"$blocked"
grep -Fq 'executable-attachment-name' <<<"$blocked"

manifest="$(moon run --target native cmd/moonmime-forensics -- CASE-2026-0042 examples/integrations/forensic-case.eml)"
grep -Fq '"schema":"moonmime.forensics.v1"' <<<"$manifest"
grep -Fq '"raw_sha256":"c48092a02135fe2292ee2b2ac2d9b30a01f11b229153a1c813bcb66dd07d7f74"' <<<"$manifest"
grep -Fq '"encoded_sha256":"fc513853d72701d4aa64a4f08f5c51b127e5823480c04eb5c90a306d938959c8"' <<<"$manifest"
grep -Fq '"filename":"disk-fragment.bin"' <<<"$manifest"

echo 'Integration evidence: gateway allow=1 quarantine=1; forensic manifests=1 attachments=1 hashes=2'
