# gen_firebase_200.ps1
# Generates firebase_200_reports.json using the same formula as seed_200_reports.sql
# Then PATCHes it into Firebase (merges – does NOT delete existing 11 reports)
#
# Usage:
#   .\gen_firebase_200.ps1
#
# Requirements: write rules temporarily set to true in Firebase Console

$DB_URL = "https://roadna-ce6a0-default-rtdb.europe-west1.firebasedatabase.app"
$OUT    = "E:\FireBase Test\backend\firebase_200_reports.json"

$statusPat = @(
    'PENDING','PENDING','PENDING','PENDING','PENDING','PENDING','PENDING','PENDING',
    'IN_PROGRESS','IN_PROGRESS','IN_PROGRESS',
    'RESOLVED','RESOLVED','RESOLVED','RESOLVED','RESOLVED',
    'REJECTED','REJECTED','REJECTED',
    'UNASSESSED'
)
$priPat    = @('LOW','LOW','LOW','MEDIUM','MEDIUM','MEDIUM','MEDIUM','HIGH','HIGH','CRITICAL')
$rejPriPat = @('LOW','LOW','LOW','MEDIUM')   # only first 4 used for REJECTED

$reports = [ordered]@{}

for ($i = 1; $i -le 200; $i++) {
    # UUID identical to SQL formula
    $hex7  = $i.ToString("x").PadLeft(7, '0')
    $hex12 = $i.ToString("x").PadLeft(12, '0')
    $uuid  = "a$hex7-beef-4abc-8def-$hex12"

    $stat = $statusPat[($i - 1) % 20]
    $pri  = $priPat   [($i - 1) % 10]

    switch ($stat) {
        'PENDING'     {
            $still  = ($i % 14) + 2
            $fixed  = $i % 3
            $rpri   = $pri
        }
        'IN_PROGRESS' {
            $still  = ($i % 20) + 10
            $fixed  = $i % 5
            $rpri   = $pri
        }
        'RESOLVED'    {
            $still  = ($i % 15) + 5
            $fixed  = ($i % 10) + 5
            $rpri   = $pri
        }
        'REJECTED'    {
            $still  = $i % 6
            $fixed  = $i % 8
            $rpri   = $rejPriPat[($i - 1) % 4]
        }
        'UNASSESSED'  {
            $still  = $i % 4
            $fixed  = 0
            $rpri   = 'LOW'
        }
    }

    $reports[$uuid] = [ordered]@{
        stillVotes = $still
        fixedVotes = $fixed
        status     = $stat
        priority   = $rpri
    }
}

# Write JSON file
$json = $reports | ConvertTo-Json -Depth 4
$json | Out-File -FilePath $OUT -Encoding utf8NoBOM
Write-Host "✓ JSON written → $OUT  ($($reports.Count) reports)"

# PATCH to Firebase  (merges — won't touch existing 11 reports)
Write-Host "Pushing to Firebase via PATCH..."
try {
    $response = Invoke-RestMethod `
        -Uri     "$DB_URL/reports.json" `
        -Method  PATCH `
        -ContentType "application/json" `
        -InFile  $OUT
    Write-Host "✓ Firebase updated successfully."
} catch {
    Write-Host "⚠ Firebase push failed: $($_.Exception.Message)"
    Write-Host "  → File saved. Use curl manually:"
    Write-Host "  curl.exe -X PATCH `"$DB_URL/reports.json`" -H `"Content-Type: application/json`" --data-binary `"@$OUT`""
}
