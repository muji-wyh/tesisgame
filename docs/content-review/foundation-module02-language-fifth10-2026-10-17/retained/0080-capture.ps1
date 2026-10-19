$ErrorActionPreference = 'Stop'
$taskRoot = 'Q:/.codex/worktrees/current-age-vocabulary/tesisgame'
$taskSource = 'build/professional-english/foundation02-fifth10-delivery-preparation-r02'
$taskOwn = 'build/professional-english/foundation02-fifth10-preparation-independent-review-r02'
$taskOutput = Join-Path $taskRoot ($taskOwn + '/capture-attempt-r01')
if (Test-Path -LiteralPath $taskOutput) { throw 'Never replay a consumed independent static capture.' }
[void][System.IO.Directory]::CreateDirectory($taskOutput)
$taskInputs = [ordered]@{}
$taskChecks = [System.Collections.Generic.List[object]]::new()
function HashBytes([byte[]] $value) { return [Convert]::ToHexString([System.Security.Cryptography.SHA256]::HashData($value)).ToLowerInvariant() }
function SaveJson([string] $name, $value) {
    $bytes = [System.Text.UTF8Encoding]::new($false).GetBytes((ConvertTo-Json -InputObject $value -Depth 100) + "`n")
    $stream = [System.IO.File]::Open((Join-Path $taskOutput $name), [System.IO.FileMode]::CreateNew, [System.IO.FileAccess]::Write)
    try { $stream.Write($bytes, 0, $bytes.Length) } finally { $stream.Dispose() }
}
function ReadBytes([string] $relative) {
    $absolute = [System.IO.Path]::GetFullPath((Join-Path $taskRoot $relative))
    if (-not $absolute.Replace('\','/').StartsWith($taskRoot + '/', [System.StringComparison]::OrdinalIgnoreCase)) { throw 'Read escaped worktree.' }
    $bytes = [System.IO.File]::ReadAllBytes($absolute)
    $row = [ordered]@{ path = $relative; bytes = $bytes.Length; raw_sha256 = (HashBytes $bytes) }
    if ($taskInputs.Contains($relative)) {
        if ($taskInputs[$relative].raw_sha256 -ne $row.raw_sha256) { throw ('Input changed: ' + $relative) }
    } else { $taskInputs[$relative] = $row }
    return ,$bytes
}
function ReadJson([string] $relative) { return ConvertFrom-Json -InputObject ([System.Text.Encoding]::UTF8.GetString((ReadBytes $relative))) }
function ReadText([string] $relative) { return [System.Text.Encoding]::UTF8.GetString((ReadBytes $relative)) }
function EqualJson($left, $right) { return (ConvertTo-Json -InputObject $left -Compress -Depth 100) -ceq (ConvertTo-Json -InputObject $right -Compress -Depth 100) }
function Check([string] $label, [bool] $ok) { $taskChecks.Add([ordered]@{ label = $label; passed = $ok }) }
function Pin($pin, [string] $prefix = '') {
    $p = $prefix + $pin.path
    $bytes = ReadBytes $p
    $hash = if ($pin.raw_sha256) { $pin.raw_sha256 } else { $pin.sha256 }
    Check ('Raw pin: ' + $p) ($bytes.Length -eq $pin.bytes -and (HashBytes $bytes) -ceq $hash)
}
SaveJson 'start.json' ([ordered]@{ schema = 1; started_at = [DateTime]::UtcNow.ToString('o'); method = 'Independent PowerShell raw-file hashes, JSON equality and literal source inspection only'; project_or_proposal_code_executed = $false; tests_or_native_executed = $false })
try {
    $inventory = ReadJson ($taskSource + '/source-inventory.json')
    Check 'Frozen r02 inventory SHA256' ((HashBytes (ReadBytes ($taskSource + '/source-inventory.json'))) -ceq '21df8c149742cb4fc63acecb033bfb7d499e10310b5467c8ff81bd715db73598')
    Check 'Thirteen frozen source members' ($inventory.files.Count -eq 13)
    foreach ($row in $inventory.files) { Pin $row ($taskSource + '/') }
    $durable = 'docs/content-review/foundation-module02-language-fifth10-delivery-proposal-review-2026-10-17'
    foreach ($dir in @('proposal','review')) {
        $packet = ReadJson ($durable + '/' + $dir + '/inventory.json')
        foreach ($row in $packet.artifacts) { Pin $row ($durable + '/' + $dir + '/') }
    }
    $contract = ReadJson ($taskSource + '/accepted-contract.json')
    $context = ReadJson ($taskSource + '/context-contract.json')
    $donors = ReadJson ($taskSource + '/donor-row-contract.json')
    $proposal = ReadJson ($durable + '/proposal/proposal.json')
    $review = ReadJson ($durable + '/review/review.json')
    $literalReview = ReadJson ($durable + '/review/source-review.json')
    Check 'Eight accepted projections' ($contract.patches.Count -eq 8)
    Check 'Sixteen complete sources match durable proposal' ($contract.sources.Count -eq 16 -and (EqualJson $contract.sources $proposal.sources))
    Check 'Accepted metadata decisions match durable independent review' (EqualJson $contract.acceptance.accepted_delivery_entries $review.accepted_delivery_entries)
    Check 'Literal source observations match durable independent review' (EqualJson $contract.source_review $literalReview)
    Check 'Context copy byte-identical to durable accepted proposal' ((HashBytes (ReadBytes ($taskSource + '/context-contract.json'))) -ceq (HashBytes (ReadBytes ($durable + '/proposal/context-preservation.json'))))
    Check 'Six exact whole-entry holds' ($contract.whole_entry_holds.Count -eq 6 -and (EqualJson $contract.whole_entry_holds $context.whole_entry_holds))
    $delta = [ordered]@{ definition = 0; example = 0; difficulty = 0 }
    foreach ($patch in $contract.patches) {
        $p = @($proposal.patches | Where-Object { $_.id -ceq $patch.id })
        $accepted = @($review.accepted_delivery_entries | Where-Object { $_.id -ceq $patch.id })
        Check ('Exact accepted before and after: ' + $patch.id) ($p.Count -eq 1 -and (EqualJson $patch.before $p[0].before) -and (EqualJson $patch.after $p[0].after))
        Check ('Independent accepted after hash: ' + $patch.id) ($accepted.Count -eq 1 -and $accepted[0].accepted_delivery_entry_json_sha256 -ceq $patch.after_entry_json_sha256)
        Check ('Exact forms, regions, modes, morphology and media: ' + $patch.id) ((EqualJson $patch.before.accepted_forms $patch.after.accepted_forms) -and (EqualJson $patch.before.regions $patch.after.regions) -and (EqualJson $patch.before.practice_modes $patch.after.practice_modes) -and (EqualJson $patch.before.morphology $patch.after.morphology) -and (EqualJson $patch.before.media $patch.after.media))
        Check ('Two references and original prefix: ' + $patch.id) ($patch.after.references.Count -eq $patch.before.references.Count + 2 -and (EqualJson @($patch.after.references | Select-Object -First $patch.before.references.Count) $patch.before.references))
        foreach ($field in @('definition','example','difficulty')) { if ($patch.before.$field -cne $patch.after.$field) { $delta[$field]++ } }
    }
    Check 'Exact four-definition, one-example, five-difficulty delta' (EqualJson $delta ([ordered]@{ definition = 4; example = 1; difficulty = 5 }))
    foreach ($source in $contract.sources) { Check ('Consulted-only source: ' + $source.id) ($source.status -ceq 'consulted' -and $source.assets_acquired -eq $false -and $null -eq $source.asset_license) }
    $contextCounts = [ordered]@{ selected_memberships=200; containing_modules=20; containing_module_expressions=10; expression_uses=90; derivative_expression_uses=81; focus_expressions=4; related_entry_boundaries=46; inherited_expression_holds=17; additional_foundation02_preservation=4 }
    foreach ($group in $contextCounts.Keys) { Check ('Complete context count: ' + $group) ($context.groups.$group.Count -eq $contextCounts[$group]) }
    Check 'Bag excluded from fixed related context' (@($context.groups.related_entry_boundaries | Where-Object { $_.id -ceq 'shopping-bag.goods-carrier.n' }).Count -eq 0)
    Check 'Fifty complete donor rows and groups' ($donors.rows.Count -eq 50 -and @($donors.rows | Group-Object { $_.history_path + '/' + $_.id }).Count -eq 50)
    $history = @{}
    foreach ($pin in $donors.history_files) { Pin $pin; $history[$pin.path] = ReadJson $pin.path }
    foreach ($row in $donors.rows) {
        $rows = $history[$row.history_path].protected_context.lexemes
        Check ('Whole donor row and original index: ' + $row.history_path + '/' + $row.id) (EqualJson $rows[$row.index] $row.whole_row)
        Check ('Exact donor multiplicity one: ' + $row.history_path + '/' + $row.id) ($row.exact_count -eq 1 -and @($rows | Where-Object { $_.entry.id -ceq $row.id }).Count -eq 1)
    }
    $evidence = ReadJson ($durable + '/proposal/evidence-pins.json')
    Check 'Thirty-nine evidence and history pins' ($evidence.evidence.Count + $evidence.history_files.Count -eq 39)
    foreach ($pin in @($evidence.evidence) + @($evidence.history_files)) { Pin $pin }
    $observations = ReadJson ($taskSource + '/author-observations.json')
    $anchors = [System.Collections.Generic.List[object]]::new()
    foreach ($anchor in $observations.exact_anchor_observations) {
        $text = ReadText $anchor.source
        $newline = if ($text.Contains("`r`n")) { "`r`n" } else { "`n" }
        $literal = $anchor.before.Replace("`r`n","`n").Replace("`n",$newline)
        $count = [regex]::Matches($text,[regex]::Escape($literal)).Count
        Check ('Literal design anchor: ' + $anchor.name) ($count -eq 1 -and $anchor.occurrences -eq 1)
        $anchors.Add([ordered]@{ source=$anchor.source; name=$anchor.name; occurrences=$count; method='Raw literal search; no transformation executed'; actual_post_bag_binding=$false })
    }
    $transform = ReadText ($taskSource + '/test-transforms.cjs')
    $bagHelpers = [System.Collections.Generic.List[object]]::new()
    foreach ($stem in @('professional-content.test.cjs.after','professional-retail-morphology.test.cjs.after','professional-retail-media.test.cjs.after')) {
        $file = 'build/professional-english/shopping-bag-delivery-preparation-r02/execution-r01/' + $stem
        $text = ReadText $file
        $helper = [regex]::Match($text,'function beforeShoppingBagImage\(entry\) \{[\s\S]*?\r?\n\}')
        Check ('Strict bag helper present: ' + $stem) ($helper.Success -and $helper.Value.Contains("assert.deepEqual(entry, patch.after"))
        $bagHelpers.Add([ordered]@{source=$file; helper_sha256=(HashBytes ([System.Text.Encoding]::UTF8.GetBytes($helper.Value))); source_only=$true})
    }
    Check 'Transform preserves exact bag helper bytes' ($transform.Contains("assert(text.includes(bagHelper[0])") -and $transform.Contains("'No new common bag reversal'"))
    foreach ($file in @('binding.cjs','prepare.cjs','projection.cjs')) { [void](ReadText ($taskSource + '/' + $file)) }
    [void](ReadText 'tools/validate-professional-content.cjs')
    [void](ReadText 'build/professional-english/shopping-bag-commit-proposal-r01/commit.cjs')
    foreach ($pin in @($taskInputs.Values)) {
        $bytes = [System.IO.File]::ReadAllBytes((Join-Path $taskRoot $pin.path))
        if ($bytes.Length -ne $pin.bytes -or (HashBytes $bytes) -cne $pin.raw_sha256) { throw ('Input changed after static capture: ' + $pin.path) }
    }
    SaveJson 'inspection.json' ([ordered]@{schema=1; status='static_inspection_complete_source_findings_separate'; checks=$taskChecks.ToArray(); checks_passed=@($taskChecks | Where-Object passed).Count; checks_failed=@($taskChecks | Where-Object { -not $_.passed }).Count; anchors=$anchors.ToArray(); bag_helpers=$bagHelpers.ToArray(); content_delta=$delta; source_modules_imported=$false; project_or_proposal_code_executed=$false; syntax_tests_native_or_transform_executed=$false; final_binding_prepared=$false; production_mutated=$false})
    SaveJson 'inputs.json' ([ordered]@{schema=1; files=@($taskInputs.Values); all_rehashed_unchanged=$true})
} catch {
    SaveJson 'failure.json' ([ordered]@{schema=1; error=$_.Exception.ToString(); partial_checks=$taskChecks.ToArray(); inputs=@($taskInputs.Values); replay_allowed=$false})
    throw
}
