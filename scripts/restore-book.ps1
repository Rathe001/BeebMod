# Put a backed-up book back where WoW reads it (Josh 2026-09-19).
#
# The client rewrites SavedVariables on every /reload and every logout, so a
# restore only sticks while the game is CLOSED. This refuses to run otherwise
# rather than write a file that is about to be overwritten.
#
# On the Forever beta the file is read back through the Data\Live link in the
# addon rather than by the client (see the README), so a restored file is what
# the next launch loads either way.
#
#   powershell -ExecutionPolicy Bypass -File scripts\restore-book.ps1
#   powershell -ExecutionPolicy Bypass -File scripts\restore-book.ps1 -From "...\BeebMod-2026-09-22-0617.lua"
param(
    [string]$From   = "",
    [string]$Dest   = "C:\Program Files (x86)\World of Warcraft\_classic_beta_\WTF\Account\960221#4\SavedVariables\BeebMod.lua",
    [string]$Backups = "C:\Users\josh\Projects\LedgerBackups",
    [switch]$Force
)

$running = Get-Process -Name "WowB", "Wow", "WowClassic" -ErrorAction SilentlyContinue
if ($running -and -not $Force) {
    Write-Host "World of Warcraft is running - close it first, or the next /reload overwrites this."
    exit 1
}

if (-not $From) {
    $newest = Get-ChildItem $Backups -Filter "BeebMod-*.lua" -ErrorAction SilentlyContinue |
        Sort-Object Length -Descending | Select-Object -First 1
    if (-not $newest) {
        Write-Host "no backups in $Backups"
        exit 1
    }
    # the biggest one, not the newest: the newest may be the empty book we are
    # trying to undo
    $From = $newest.FullName
}

if (-not (Test-Path $From)) {
    Write-Host "no such backup: $From"
    exit 1
}

# never throw away what is there now, however small it looks
if (Test-Path $Dest) {
    $stamp = (Get-Item $Dest).LastWriteTime.ToString("yyyy-MM-dd-HHmm")
    $aside = Join-Path $Backups "BeebMod-$stamp-replaced.lua"
    if (-not (Test-Path $aside)) { Copy-Item $Dest $aside }
    Write-Host "set aside the current file as $(Split-Path $aside -Leaf)"
}

Copy-Item $From $Dest -Force
$kb = [int]((Get-Item $Dest).Length / 1KB)
Write-Host "restored $(Split-Path $From -Leaf) -> BeebMod.lua ($kb KB)"
