[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$repoRoot = $PSScriptRoot
$scriptPaths = (Get-ChildItem '*.ps1' -Path $repoRoot -Recurse)

foreach ($scriptPath in $scriptPaths) {
    Write-Information "==> Checking $scriptPath" -InformationAction Continue
    Invoke-ScriptAnalyzer -Path $scriptPath
}
