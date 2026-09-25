# Cut a release (Josh 2026-09-25). Everything but the push:
#
#   1. refuses unless the working tree is clean and both test suites are green
#   2. writes the version into BeebMod.toc and into Core/Init.lua's fallback
#   3. turns CHANGELOG.md's "## Unreleased" into "## <version>" - the section
#      the release workflow hands CurseForge as this file's notes
#   4. commits those three files and makes the annotated tag v<version>
#
# and then prints the one command that publishes it. Pushing the tag is what
# starts .github/workflows/release.yml.
#
#   powershell -ExecutionPolicy Bypass -File scripts\cut-release.ps1 -Version 0.1.0-beta.2
param(
    [Parameter(Mandatory = $true)]
    [string]$Version
)

$ErrorActionPreference = "Stop"
Set-Location (Split-Path $PSScriptRoot -Parent)

function Fail($msg) {
    Write-Host "not released: $msg"
    exit 1
}

# MAJOR.MINOR.PATCH, and -beta.N (or -alpha.N) while the client is in beta
if ($Version -notmatch '^\d+\.\d+\.\d+(-(alpha|beta)\.\d+)?$') {
    Fail "a version looks like 0.1.0-beta.2"
}
$tag = "v$Version"
if (git tag --list $tag) {
    Fail "$tag already exists"
}
if (git status --porcelain) {
    Fail "the working tree has changes; commit them first, so the release is exactly what was tested"
}

foreach ($suite in @("tests/run.lua", "tests/load.lua")) {
    $out = & lua $suite 2>&1
    if ($LASTEXITCODE -ne 0) {
        $out | Select-Object -Last 15 | ForEach-Object { Write-Host $_ }
        Fail "$suite is not green"
    }
}

# the changelog must have something to say, under a heading this turns into the version
$changelog = Get-Content CHANGELOG.md -Raw
if ($changelog -notmatch '(?m)^## Unreleased\r?\n') {
    Fail "CHANGELOG.md has no '## Unreleased' section to release"
}
$section = [regex]::Match($changelog, '(?ms)^## Unreleased\r?\n(.*?)(?=^## |\z)').Groups[1].Value
if (-not $section.Trim()) {
    Fail "the Unreleased section of CHANGELOG.md is empty"
}

# the files are LF (.gitattributes); written back as UTF-8 without a BOM
$utf8 = New-Object System.Text.UTF8Encoding($false)
function Rewrite($path, $pattern, $replacement) {
    $text = [System.IO.File]::ReadAllText((Resolve-Path $path))
    $new = [regex]::Replace($text, $pattern, $replacement, 'Multiline')
    if ($new -eq $text) {
        Fail "nothing to change in $path"
    }
    [System.IO.File]::WriteAllText((Resolve-Path $path), $new, $utf8)
}

Rewrite "BeebMod.toc" '^## Version: .*$' "## Version: $Version"
Rewrite "Core/Init.lua" '(GetAddOnMetadata\(ADDON, "Version"\) or ")[^"]*(")' "`${1}$Version`${2}"
Rewrite "CHANGELOG.md" '^## Unreleased$' "## $Version"

git add BeebMod.toc Core/Init.lua CHANGELOG.md
git commit -q -m "BeebMod $Version"
git tag -a $tag -m "BeebMod $Version"

Write-Host "released $tag locally: committed and tagged"
Write-Host "to publish it (GitHub, and CurseForge once set up):"
Write-Host "    git push origin main $tag"
