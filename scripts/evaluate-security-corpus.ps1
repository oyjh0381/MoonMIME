$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$corpusRoot = Join-Path $repoRoot 'security-corpus'
$manifest = Get-Content -LiteralPath (Join-Path $corpusRoot 'manifest.tsv')
$work = Join-Path ([IO.Path]::GetTempPath()) ('moonmime-corpus-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $work | Out-Null
$tp = $tn = $fp = $fn = 0

try {
  foreach ($line in $manifest) {
    $file, $label, $expected = $line -split "`t"
    $inputPath = Join-Path $corpusRoot $file
    $materializedPath = Join-Path $work $file
    $content = [IO.File]::ReadAllText($inputPath)
    $content = $content.Replace("`r`n", "`n").Replace("`r", "`n")
    if ($file -ne 'attack_bare_lf.eml') {
      $content = $content.Replace("`n", "`r`n")
    }
    [IO.File]::WriteAllText($materializedPath, $content, [Text.UTF8Encoding]::new($false))
    $inputPath = $materializedPath
    $output = moon -C $repoRoot run --target native cmd/moonmime -- audit $inputPath --compatible --json
    if ($LASTEXITCODE -ne 0) { throw "audit command failed for $file" }
    $found = if ($expected -eq 'none') {
      $output -match '"findings":\[\]'
    } else {
      $output -match ('"code":"' + [regex]::Escape($expected) + '"')
    }
    if ($label -eq 'positive' -and $found) { $tp++ }
    elseif ($label -eq 'positive') { $fn++ }
    elseif ($found) { $tn++ }
    else { $fp++ }
  }
  Write-Output "MoonMIME synthetic corpus: TP=$tp TN=$tn FP=$fp FN=$fn"
  if ($tp -ne 6 -or $tn -ne 4 -or $fp -ne 0 -or $fn -ne 0) { exit 1 }
} finally {
  $resolved = (Resolve-Path $work).Path
  $tempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\')
  if (-not $resolved.StartsWith($tempRoot + '\')) { throw 'unexpected cleanup path' }
  Remove-Item -LiteralPath $resolved -Recurse -Force
}
