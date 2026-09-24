# Copy the Ledger book out of WoW's WTF folder, where exactly one file stands
# between you and every character you have ever met (Josh 2026-09-19).
#
# The client rewrites SavedVariables on every logout and /reload, so the moment
# the addon comes up empty, the next logout is what actually destroys the data.
# This keeps dated copies outside the game folder, and prunes to the last 20.
#
#   powershell -ExecutionPolicy Bypass -File scripts\backup-book.ps1
param(
    [string]$Source = "C:\Program Files (x86)\World of Warcraft\_classic_beta_\WTF\Account\960221#4\SavedVariables\BeebMod.lua",
    [string]$Dest   = "C:\Users\josh\Projects\LedgerBackups",
    [int]$Keep      = 20
)

if (-not (Test-Path $Source)) {
    Write-Host "no book at $Source"
    exit 1
}

if (-not (Test-Path $Dest)) { New-Item -ItemType Directory -Path $Dest | Out-Null }

# named for when the GAME wrote it, not for when this ran: two backups of the
# same save are the same backup
$stamp = (Get-Item $Source).LastWriteTime.ToString("yyyy-MM-dd-HHmm")
$target = Join-Path $Dest "BeebMod-$stamp.lua"
if (Test-Path $target) {
    Write-Host "already have $stamp"
} else {
    Copy-Item $Source $target
    $kb = [int]((Get-Item $target).Length / 1KB)
    Write-Host "saved $target ($kb KB)"
}

# NEVER PRUNE THE BIGGEST (Josh 2026-09-19). While the client refuses to read
# the book back, every save it writes is an EMPTY book - so the newest copies
# are the worthless ones, and pruning by age alone would quietly delete the
# 1,913-character file and keep twenty copies of nothing.
$all = Get-ChildItem $Dest -Filter "BeebMod-*.lua" | Sort-Object Length -Descending
$biggest = $all | Select-Object -First 1
$all | Sort-Object LastWriteTime -Descending |
    Select-Object -Skip $Keep |
    Where-Object { $_.FullName -ne $biggest.FullName } |
    ForEach-Object { Remove-Item $_.FullName; Write-Host "pruned $($_.Name)" }
