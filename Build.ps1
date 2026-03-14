[CmdletBinding()]
param(
    [string]$ConfigPath = 'config/build-config.psd1',
    [switch]$UseInstalled
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$repoRoot = $PSScriptRoot
. (Join-Path $repoRoot 'lib/QCacheGrind.Build.ps1')

Write-Step 'Loading build configuration'
$resolvedConfigPath = Resolve-RepoPath -BasePath $repoRoot -Path $ConfigPath
Assert-PathExistence -Path $resolvedConfigPath -Label 'Config file'
$config = Import-PowerShellDataFile -LiteralPath $resolvedConfigPath

$distDir = Resolve-RepoPath -BasePath $repoRoot -Path $config.DistDir
$outputDir = Resolve-RepoPath -BasePath $repoRoot -Path $config.OutputDir
$issTemplatePath = Resolve-RepoPath -BasePath $repoRoot -Path $config.IssTemplatePath
$issOutputPath = Resolve-RepoPath -BasePath $repoRoot -Path $config.IssOutputPath
$craftRoot = Resolve-RepoPath -BasePath $repoRoot -Path $config.CraftRoot
$craftBin = Join-Path $craftRoot 'bin'
$winDeployQt = Join-Path $craftBin 'windeployqt.exe'
$qcachegrindExe = Resolve-RepoPath -BasePath $craftRoot -Path $config.BuiltExePath
$iconPath = Resolve-RepoPath -BasePath $craftRoot -Path $config.IconPath
$versionHeaderPath = if ($config.VersionHeaderPath) { Resolve-RepoPath -BasePath $craftRoot -Path $config.VersionHeaderPath } else { $null }
$cmakeCachePath = if ($config.CMakeCachePath) { Resolve-RepoPath -BasePath $craftRoot -Path $config.CMakeCachePath } else { $null }
$graphvizBin = Resolve-RepoPath -BasePath $repoRoot -Path $config.GraphvizBin
$rcEdit = Resolve-ExecutablePath -NameOrPath $config.RcEdit -BasePath $repoRoot
$vsWhere = Resolve-ExecutablePath -NameOrPath $config.VsWhere -BasePath $repoRoot

try {
    $innoCompiler = Resolve-ExecutablePath -NameOrPath $config.InnoCompiler -BasePath $repoRoot
}
catch {
    if ($config.InnoCompiler -ieq 'ISCC.exe') {
        $innoCompiler = Find-InnoSetupCompiler
    }
    else {
        throw
    }
}

$dumpBin = Find-DumpBin -VsWherePath $vsWhere

Write-Step 'Validating required commands and paths'
Assert-CommandExistence -Name 'craft'
Assert-PathExistence -Path $craftRoot -Label 'Craft root'
Assert-PathExistence -Path $craftBin -Label 'Craft bin directory'
Assert-PathExistence -Path $winDeployQt -Label 'windeployqt.exe'
Assert-PathExistence -Path $graphvizBin -Label 'Graphviz bin directory'
Assert-PathExistence -Path $issTemplatePath -Label 'Inno Setup template'

Write-Step 'Running builds from the current Craft shell'
Invoke-CraftBuild -Packages $config.CraftPackages -IgnoreInstalled:(-not $UseInstalled)

Write-Step 'Validating build outputs'
Assert-PathExistence -Path $qcachegrindExe -Label 'Built qcachegrind.exe'
Assert-PathExistence -Path $iconPath -Label 'KCacheGrind icon'

Write-Step 'Resolving application version from Craft outputs'
$resolvedAppVersion = Resolve-AppVersion -VersionHeaderPath $versionHeaderPath -CMakeCachePath $cmakeCachePath

Write-Step 'Preparing distribution and output directories'
New-CleanDirectory -Path $distDir

$stagedExe = Join-Path $distDir 'QCacheGrind.exe'

Write-Step 'Staging QCacheGrind executable'
Copy-Item -LiteralPath $qcachegrindExe -Destination $stagedExe -Force

Write-Step 'Deploying Qt runtime with windeployqt'
Invoke-WinDeployQt -WinDeployQtPath $winDeployQt -ExecutablePath $stagedExe

Write-Step 'Copying required non-Qt runtime DLLs'
Copy-RequiredFileSet -SourceDirectory $craftBin -Files $config.ExtraDlls -DestinationDirectory $distDir

Write-Step 'Copying Graphviz runtime files'
Copy-GraphvizRuntime -GraphvizBin $graphvizBin -DumpBinPath $dumpBin -Roots $config.GraphvizRoots -DestinationDirectory $distDir

Write-Step 'Applying icon to QCacheGrind.exe'
Set-ExecutableIcon -RcEdit $rcEdit -ExecutablePath $stagedExe -IconPath $iconPath

Write-Step 'Rendering Inno Setup script'
$templateValues = @{
    InstallerAppId = $config.InstallerAppId
    AppName = $config.AppName
    AppVersion = $resolvedAppVersion
    Publisher = $config.Publisher
    OutputDir = $outputDir
    InstallerBaseName = $config.InstallerBaseName
    DistDir = $distDir
}
Write-TemplateFile -TemplatePath $issTemplatePath -DestinationPath $issOutputPath -Values $templateValues

Write-Step 'Building installer with Inno Setup'
Invoke-InnoSetup -CompilerPath $innoCompiler -IssPath $issOutputPath

$installerPath = Join-Path $outputDir "$($config.InstallerBaseName).exe"
if (Test-Path -LiteralPath $installerPath) {
    Write-Step "Installer created at $installerPath"
}
else {
    Write-Warning "Inno Setup completed, but the expected installer was not found at $installerPath"
}
