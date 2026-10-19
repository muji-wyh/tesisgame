$ErrorActionPreference = 'Stop'
$root = 'Q:/.codex/worktrees/current-age-vocabulary/tesisgame'
$fixture = 'build/professional-english/domain-runtime-web-fixture-r04'
$attempt = $fixture + '/attempt-001'
$project = $attempt + '/project'
$web = $attempt + '/web'
$rootEvidence = 'build/professional-english/domain-runtime-web-root-r04'
$own = 'docs/qa/professional-domain-web-runtime-r01/r04-export-review'
Set-Location -LiteralPath $root
$utf8 = [System.Text.UTF8Encoding]::new($false)
function Check($condition, [string]$message) { if (-not $condition) { throw $message } }
function Read-Json([string]$p) { Get-Content -LiteralPath $p -Raw | ConvertFrom-Json }
function Raw([string]$p) { (Get-FileHash -LiteralPath $p -Algorithm SHA256).Hash.ToLowerInvariant() }
function Pin([string]$p) { [ordered]@{path = $p; bytes = (Get-Item -LiteralPath $p).Length; sha256 = (Raw $p)} }
function Hash-Bytes([byte[]]$bytes) { [Convert]::ToHexString([System.Security.Cryptography.SHA256]::HashData($bytes)).ToLowerInvariant() }
function Md5-Bytes([byte[]]$bytes) { [Convert]::ToHexString([System.Security.Cryptography.MD5]::HashData($bytes)).ToLowerInvariant() }
function Triples($rows) { (@($rows | ForEach-Object { $_.path + '|' + $_.bytes + '|' + $_.sha256 } | Sort-Object) -join "`n") }
function Save-New([string]$name, $value) {
  $p = Join-Path $root ($own + '/' + $name)
  $bytes = $utf8.GetBytes(($value | ConvertTo-Json -Depth 30) + "`n")
  $s = [System.IO.File]::Open($p, [System.IO.FileMode]::CreateNew, [System.IO.FileAccess]::Write)
  try { $s.Write($bytes, 0, $bytes.Length) } finally { $s.Dispose() }
}
$checks = [System.Collections.Generic.List[object]]::new()
function Bound([string]$p, $row, [string]$kind) {
  $actual = Pin $p
  Check ($actual.sha256 -ceq $row.sha256) ('Hash mismatch: ' + $p)
  if ($null -ne $row.bytes) { Check ($actual.bytes -eq $row.bytes) ('Length mismatch: ' + $p) }
  $checks.Add([ordered]@{kind = $kind; path = $p; bytes = $actual.bytes; sha256 = $actual.sha256})
}
Save-New 'inspection-start-r03.json' ([ordered]@{schema = 1; started_at = [DateTime]::UtcNow.ToString('o'); inspector = (Pin ($own + '/inspect-r03.ps1')); method = 'Read-only JSON/source/hash review and direct binary PCK parsing; no artifact producer or native/browser/test replay.'})
$prep = Read-Json ($attempt + '/preparation.json')
$export = Read-Json ($attempt + '/export-receipt.json')
$proof = Read-Json ($attempt + '/web-pack-proof.json')
$manifest = Read-Json ($attempt + '/web-pack-manifest.json')
$preparedReview = Read-Json ($rootEvidence + '/prepared-inspection.json')
$references = Read-Json ($fixture + '/source-references.json')
$inventory = Read-Json ($fixture + '/inventory.json')
Check ($export.ok -and $proof.ok) 'Retained export and proof must have succeeded.'
Check ($export.synthetic_only -and -not $export.browser_execution) 'Unexpected export scope.'
Check ($prep.synthetic.ready_modules -eq 1 -and $prep.release.ready_modules -eq 1 -and $prep.release.unavailable_modules -eq 199) 'Unexpected synthetic readiness.'
Check ($preparedReview.production_ready_modules -eq 0 -and $preparedReview.synthetic_ready_modules -eq 1) 'Unexpected root readiness distinction.'
Bound ($fixture + '/inventory.json') $prep.harness_inventory 'harness'
Bound ($fixture + '/source-references.json') $prep.source_references 'source-references'
Bound ($attempt + '/preparation.json') $export.preparation 'preparation'
Check ((Raw ($attempt + '/preparation.json')) -ceq $preparedReview.preparation_sha256) 'Root inspected a different preparation.'
foreach ($row in $inventory.files) { Bound ($fixture + '/' + $row.path) $row 'frozen-harness-member' }
Check ($references.files.Count -eq 43) 'Expected 43 live root refs.'
foreach ($row in $references.files) { Bound $row.path $row 'current-live-root-ref' }
$third10 = @('data/professional/lexemes/foundation-module02.json','data/professional/sources.json','tests/professional-content.test.cjs','tests/professional-retail-morphology.test.cjs','tests/godot/professional_retail_morphology_tests.gd')
Check (@($references.files | Where-Object { $_.path -in $third10 }).Count -eq 0) 'A live ref overlaps the third10 mutation.'
foreach ($stage in @('prepare','export')) {
  $receipt = Read-Json ($rootEvidence + '/' + $stage + '/receipt.json')
  Check ($receipt.ok -and $receipt.exit_code -eq 0 -and $null -eq $receipt.signal -and $null -eq $receipt.error -and $receipt.inputs_unchanged) ('Root stage failed: ' + $stage)
  Check ($receipt.stage_source_before -ceq $receipt.stage_source_after) ('Stage source drift: ' + $stage)
  Check ((Raw ($fixture + '/' + $stage + '.cjs')) -ceq $receipt.stage_source_before) ('Stage source no longer matches: ' + $stage)
  Check ((Raw ($rootEvidence + '/' + $stage + '/execution.log')) -ceq $receipt.log_sha256) ('Root stage log changed: ' + $stage)
  foreach ($row in $receipt.inputs) { Bound $row.path $row ('root-' + $stage + '-input') }
}
Check ($prep.project_bindings.Count -eq 31) 'Expected 31 prepared project bindings.'
foreach ($row in $prep.project_bindings) { Bound ($project + '/' + $row.path) $row 'prepared-project-binding' }
foreach ($row in $prep.release.source_inventory) {
  Bound ($project + '/' + $row.path) $row 'prepared-source'
  Bound ($project + '/build/audited-domain-release/source/' + $row.path) $row 'retained-source-snapshot'
}
foreach ($row in $prep.release.supporting_inventory) { Bound ($project + '/' + $row.path) $row 'prepared-supporting-input' }
foreach ($row in $prep.release.contracts) { Bound $row.path $row 'release-contract' }
Check (($prep.release | ConvertTo-Json -Depth 20 -Compress) -ceq ($export.release | ConvertTo-Json -Depth 20 -Compress)) 'Export release differs from preparation.'
Check (($prep.release | ConvertTo-Json -Depth 20 -Compress) -ceq ($preparedReview.release_verification | ConvertTo-Json -Depth 20 -Compress)) 'Root inspected a different prepared release.'
Check (($prep.release | ConvertTo-Json -Depth 20 -Compress) -ceq ($export.domain_pack.release | ConvertTo-Json -Depth 20 -Compress)) 'Pack receipt release differs.'
Check ((Triples $prep.release.generated_inventory) -ceq (Triples $manifest.generated_inventory)) 'Manifest generated inventory differs.'
Check ((Triples $prep.release.generated_inventory) -ceq (Triples $proof.generated_inventory)) 'Native generated inventory differs.'
Check ((Triples $proof.generated_inventory) -ceq (Triples $export.domain_pack.native_proof.generated_inventory)) 'Receipt proof differs.'
foreach ($property in $manifest.pin_constants.PSObject.Properties) {
  Check ($proof.pin_constants.($property.Name) -ceq $property.Value) ('Native pin mismatch: ' + $property.Name)
  Check ($export.domain_pack.native_proof.pin_constants.($property.Name) -ceq $property.Value) ('Receipt pin mismatch: ' + $property.Name)
}
Check ($manifest.pin_constants.PSObject.Properties.Name.Count -eq 7) 'Expected exactly seven pin constants.'
Check ($proof.pin_constants.DESCRIPTOR_SHA256 -ceq $prep.release.descriptor.sha256) 'Descriptor hash does not equal the loaded pin proof.'
Check ($proof.pin_constants.DESCRIPTOR_BYTES -eq $prep.release.descriptor.bytes) 'Descriptor size does not equal the loaded pin proof.'
Bound ($project + '/' + $prep.release.pin.path.Substring(6)) $prep.release.pin 'generated-pin-source'
foreach ($row in $export.outputs) { Bound ($web + '/' + $row.path) $row 'actual-web-output' }
$actualOutputPaths = @(Get-ChildItem -LiteralPath $web -File -Recurse | ForEach-Object { [System.IO.Path]::GetRelativePath((Join-Path $root $web), $_.FullName).Replace('\','/') } | Sort-Object)
Check (($actualOutputPaths -join '|') -ceq (($export.outputs.path | Sort-Object) -join '|')) 'Export file allowlist differs.'
Check ($export.outputs.Count -eq 15 -and $export.media.resources -eq 6) 'Unexpected output/media count.'
Bound ($web + '/index.pck') $export.domain_pack.decoded_pack 'native-proven-pack'

# Read the unencrypted Godot 4 PCK directory and payload bytes directly; no engine is loaded.
$packBytes = [System.IO.File]::ReadAllBytes((Join-Path $root ($web + '/index.pck')))
$stream = [System.IO.MemoryStream]::new($packBytes, $false)
$reader = [System.IO.BinaryReader]::new($stream)
$entries = [System.Collections.Generic.List[object]]::new()
$payloads = @{}
try {
  Check ([System.Text.Encoding]::ASCII.GetString($reader.ReadBytes(4)) -ceq 'GDPC') 'Wrong PCK magic.'
  $version = $reader.ReadUInt32(); $major = $reader.ReadUInt32(); $minor = $reader.ReadUInt32(); $patch = $reader.ReadUInt32(); $flags = $reader.ReadUInt32()
  $fileBase = $reader.ReadUInt64(); $directoryOffset = $reader.ReadUInt64()
  Check ($version -eq 4 -and $flags -eq 2 -and $fileBase -eq 112) 'Unexpected PCK header.'
  Check ($directoryOffset -gt $fileBase -and $directoryOffset -lt $packBytes.Length) 'Directory bounds are invalid.'
  $stream.Position = $directoryOffset; $count = $reader.ReadUInt32()
  Check ($count -eq 76) 'Unexpected PCK directory count.'
  for ($i = 0; $i -lt $count; $i++) {
    $nameLength = $reader.ReadUInt32(); Check ($nameLength -gt 0 -and $nameLength -le 2048) 'Invalid pack path length.'
    $name = [System.Text.Encoding]::UTF8.GetString($reader.ReadBytes($nameLength)).TrimEnd([char]0)
    Check (-not $payloads.ContainsKey($name) -and -not $name.Contains('..') -and -not $name.Contains('\') -and -not $name.StartsWith('/')) ('Noncanonical pack path: ' + $name)
    $offset = $reader.ReadUInt64(); $size = $reader.ReadUInt64(); $md5 = [Convert]::ToHexString($reader.ReadBytes(16)).ToLowerInvariant(); $entryFlags = $reader.ReadUInt32()
    Check ($entryFlags -eq 0) ('Encrypted or unsupported entry: ' + $name)
    Check ($fileBase + $offset + $size -le $directoryOffset) ('Payload leaves data region: ' + $name)
    $payload = [byte[]]::new([int]$size); [Array]::Copy($packBytes, [long]($fileBase + $offset), $payload, 0L, [long]$size)
    Check ((Md5-Bytes $payload) -ceq $md5) ('PCK directory MD5 mismatch: ' + $name)
    $payloads[$name] = $payload
    $entries.Add([pscustomobject][ordered]@{path = $name; offset = $offset; bytes = $size; sha256 = (Hash-Bytes $payload); md5 = $md5; flags = $entryFlags})
  }
  Check ($stream.Position -eq $stream.Length) 'Trailing bytes after the PCK directory.'
} finally { $reader.Dispose(); $stream.Dispose() }
$priorEnd = 0L
foreach ($entry in @($entries | Sort-Object offset)) { Check ($entry.offset -ge $priorEnd) ('Overlapping PCK payload: ' + $entry.path); $priorEnd = $entry.offset + $entry.bytes }
$expectedGenerated = @($prep.release.generated_inventory | ForEach-Object { $_.path.Substring(6) } | Sort-Object)
$packedGenerated = @($entries | Where-Object { $_.path.StartsWith('data/professional/domain-policy/generated/') } | ForEach-Object path | Sort-Object)
Check (($expectedGenerated -join '|') -ceq ($packedGenerated -join '|')) 'Actual pack generated inventory differs.'
foreach ($row in $prep.release.generated_inventory) {
  $name = $row.path.Substring(6); $entry = $entries | Where-Object path -CEQ $name
  Check ($entry.sha256 -ceq $row.sha256 -and $entry.bytes -eq $row.bytes) ('Actual generated payload mismatch: ' + $name)
  Bound ($project + '/' + $name) $row 'generated-project-payload'
}

$seen = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
$queue = [System.Collections.Generic.Queue[string]]::new()
$edges = [System.Collections.Generic.List[object]]::new()
$queue.Enqueue('res://fixture/main.gd'); $queue.Enqueue('res://fixture/verify_pack.gd')
$referencePattern = '[''"](res://[^''"]+\.gd)[''"]'
while ($queue.Count -gt 0) {
  $from = $queue.Dequeue(); if (-not $seen.Add($from)) { continue }
  $source = Get-Content -LiteralPath ($project + '/' + $from.Substring(6)) -Raw
  foreach ($match in [regex]::Matches($source, $referencePattern)) {
    $to = $match.Groups[1].Value; $edges.Add([pscustomobject][ordered]@{from = $from; to = $to}); $queue.Enqueue($to)
  }
}
$scripts = @($seen | Sort-Object)
Check (($scripts -join '|') -ceq (($preparedReview.scripts | Sort-Object) -join '|')) 'Direct source closure differs from root inspection.'
$edgeRows = @($edges | ForEach-Object { $_.from + '|' + $_.to } | Sort-Object)
$rootEdgeRows = @($preparedReview.edges | ForEach-Object { $_.from + '|' + $_.to } | Sort-Object)
Check (($edgeRows -join "`n") -ceq ($rootEdgeRows -join "`n")) 'Direct dependency edges differ from root inspection.'
$compiled = [System.Collections.Generic.List[object]]::new()
foreach ($script in $scripts) {
  if ($script -ceq 'res://fixture/verify_pack.gd') { continue }
  $name = $script.Substring(6); $remapName = $name + '.remap'
  Check ($payloads.ContainsKey($remapName)) ('Missing exported script remap: ' + $script)
  $remap = [System.Text.Encoding]::UTF8.GetString($payloads[$remapName])
  $match = [regex]::Match($remap, 'path="(res://[^"]+\.gdc)"')
  Check ($match.Success) ('Missing compiled target in remap: ' + $script)
  $target = $match.Groups[1].Value.Substring(6)
  Check ($payloads.ContainsKey($target) -and $payloads[$target].Length -gt 0) ('Missing compiled target: ' + $target)
  $compiled.Add([ordered]@{source = $script; remap = $remapName; compiled = $target; bytes = $payloads[$target].Length; sha256 = (Hash-Bytes $payloads[$target])})
}
Check ($compiled.Count -eq 21 -and @($entries | Where-Object { $_.path.EndsWith('.gdc') }).Count -eq 21) 'Compiled script closure is not exact.'
Check (@($entries | Where-Object { $_.path.StartsWith('build/') -or $_.path.StartsWith('professional-media/') }).Count -eq 0) 'PCK includes excluded build history or loose media.'
$syntheticIndex = Read-Json ($project + '/data/professional/domain-policy/generated/index.json')
$productionIndex = Read-Json 'data/professional/domain-policy/generated/index.json'
Check (@($syntheticIndex.modules | Where-Object state -eq 'ready').Count -eq 1) 'Prepared index must have one synthetic ready module.'
Check (@($productionIndex.modules | Where-Object state -eq 'ready').Count -eq 0) 'Current production index unexpectedly ready.'
$snapshotDifferences = @($third10 | Select-Object -First 2 | ForEach-Object { [ordered]@{path = $_; prepared_source_sha256 = (Raw ($project + '/' + $_)); current_production_sha256 = (Raw $_)} })
$evidencePaths = @(($fixture + '/inventory.json'),($fixture + '/source-references.json'),($fixture + '/export.cjs'),($fixture + '/export_presets.cfg'),($attempt + '/preparation.json'),($attempt + '/export-receipt.json'),($attempt + '/web-pack-manifest.json'),($attempt + '/web-pack-proof.json'),($attempt + '/raw-pack.log'),($attempt + '/export.log'),($attempt + '/import.log'),($rootEvidence + '/prepared-inspection.json'),($rootEvidence + '/prepare/receipt.json'),($rootEvidence + '/export/receipt.json'),($rootEvidence + '/export/execution.log'))
Save-New 'inspection-r03.json' ([ordered]@{
  schema = 1; status = 'independent_actual_export_artifact_review_no_blocker'; reviewer = 'Codex disposal_test_review'; reviewed_at = [DateTime]::UtcNow.ToString('o')
  inspector = (Pin ($own + '/inspect-r03.ps1')); method = 'Read-only direct file hashing, retained command evidence inspection, source dependency tracing and independent binary PCK directory/payload parsing.'
  evidence = @($evidencePaths | ForEach-Object { Pin $_ }); hash_checks = $checks.Count; checked_files = $checks
  live_root_refs = 43; third10_overlap_with_live_refs = @(); project_bindings = 31; prepared_source_rows = $prep.release.source_inventory.Count; synthetic_ready_modules = 1; production_ready_modules = 0; snapshot_vs_current_production = $snapshotDifferences
  output_files = $export.outputs; loose_media = $export.media; pck = [ordered]@{file = (Pin ($web + '/index.pck')); format_version = $version; engine = @($major,$minor,$patch); flags = $flags; file_base = $fileBase; directory_offset = $directoryOffset; entries = $entries.Count; all_payload_md5_valid = $true; all_payload_bounds_nonoverlapping = $true; directory_ends_at_file_end = $true; generated_payloads_match_prepared_and_native_proof = $true; files = $entries}
  script_closure = [ordered]@{scripts = $scripts; edges = $edges; compiled = $compiled; external_entry = 'res://fixture/verify_pack.gd'; static_closure_scripts = $scripts.Count; dependency_edges = $edges.Count; compiled_scripts_in_actual_pack = $compiled.Count}
  native_proof = $proof; reviewer_replayed_runtime_or_producer = $false; production_modified_by_reviewer = $false; browser_acceptance = $false
  limits = @('The retained native proof loaded the exported pin; this independent review hashes and inspects its bound artifacts without rerunning Godot.', 'Compiled bytecode is present for the complete static literal dependency closure; this is not execution coverage or decompilation of every compiled script.', 'The one-ready-module phrase fixture is synthetic and uses its immutable prepared source. Later third10 production data changes do not rewrite that snapshot and do not overlap the 43 live root refs.', 'No browser, full GameUI, six-mode, settlement, audibility, device performance, heap reclamation, human, specialist, curriculum or release approval is granted.')
})
[ordered]@{ok = $true; report = ($own + '/inspection-r03.json'); report_sha256 = (Raw ($own + '/inspection-r03.json')); hash_checks = $checks.Count; pck_entries = $entries.Count; closure_scripts = $scripts.Count; compiled_scripts = $compiled.Count; dependency_edges = $edges.Count} | ConvertTo-Json -Depth 3
