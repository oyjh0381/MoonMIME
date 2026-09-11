$ErrorActionPreference = 'Stop'

$clean = & moon run --target native cmd/moonmime-gateway -- examples/integrations/gateway-clean.eml
if ($LASTEXITCODE -ne 0 -or $clean -notmatch '"action":"allow"') {
  throw 'gateway clean-message decision did not allow'
}

$blocked = & moon run --target native cmd/moonmime-gateway -- examples/integrations/gateway-ambiguous.eml
if ($LASTEXITCODE -ne 3 -or $blocked -notmatch '"action":"quarantine"') {
  throw 'gateway ambiguous-message decision did not quarantine'
}
foreach ($code in @('conflicting-singleton-header', 'unsafe-attachment-filename', 'executable-attachment-name')) {
  if ($blocked -notmatch [regex]::Escape($code)) {
    throw "gateway evidence missing $code"
  }
}

$manifest = & moon run --target native cmd/moonmime-forensics -- CASE-2026-0042 examples/integrations/forensic-case.eml
if ($LASTEXITCODE -ne 0) {
  throw 'forensic manifest command failed'
}
foreach ($evidence in @(
  '"schema":"moonmime.forensics.v1"',
  '"raw_sha256":"c48092a02135fe2292ee2b2ac2d9b30a01f11b229153a1c813bcb66dd07d7f74"',
  '"encoded_sha256":"fc513853d72701d4aa64a4f08f5c51b127e5823480c04eb5c90a306d938959c8"',
  '"filename":"disk-fragment.bin"'
)) {
  if ($manifest -notmatch [regex]::Escape($evidence)) {
    throw "forensic evidence missing $evidence"
  }
}

Write-Output 'Integration evidence: gateway allow=1 quarantine=1; forensic manifests=1 attachments=1 hashes=2'
