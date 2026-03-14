Set-StrictMode -Version Latest

function Write-Step {
    param(
        [Parameter(Mandatory)]
        [string]$Message
    )

    Write-Information "==> $Message" -InformationAction Continue
}

function Resolve-RepoPath {
    param(
        [Parameter(Mandatory)]
        [string]$BasePath,
        [Parameter(Mandatory)]
        [string]$Path
    )

    if ([System.IO.Path]::IsPathRooted($Path)) {
        return $Path
    }

    return [System.IO.Path]::GetFullPath((Join-Path $BasePath $Path))
}

function Assert-PathExistence {
    param(
        [Parameter(Mandatory)]
        [string]$Path,
        [Parameter(Mandatory)]
        [string]$Label
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "$Label not found: $Path"
    }
}

function Assert-CommandExistence {
    param(
        [Parameter(Mandatory)]
        [string]$Name
    )

    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        throw "Required command not found in PATH: $Name"
    }
}

function Resolve-ExecutablePath {
    param(
        [Parameter(Mandatory)]
        [string]$NameOrPath,
        [string]$BasePath
    )

    if ([System.IO.Path]::IsPathRooted($NameOrPath) -or $NameOrPath.Contains('\') -or $NameOrPath.Contains('/')) {
        $resolvedPath = if ($BasePath) {
            Resolve-RepoPath -BasePath $BasePath -Path $NameOrPath
        }
        else {
            $NameOrPath
        }

        Assert-PathExistence -Path $resolvedPath -Label 'Executable path'
        return $resolvedPath
    }

    $command = Get-Command $NameOrPath -ErrorAction SilentlyContinue
    if (-not $command) {
        throw "Required command not found in PATH: $NameOrPath"
    }

    foreach ($candidate in @($command.Path, $command.Source, $command.Definition)) {
        if ($candidate -and (Test-Path -LiteralPath $candidate)) {
            return $candidate
        }
    }

    throw "Unable to resolve an executable path for command: $NameOrPath"
}

function Find-InnoSetupCompiler {
    $roots = @(
        $env:ProgramFiles,
        ${env:ProgramFiles(x86)},
        $(if ($env:LOCALAPPDATA) { Join-Path $env:LOCALAPPDATA 'Programs' })
    ) | Where-Object { $_ -and (Test-Path -LiteralPath $_) } | Select-Object -Unique

    $candidates = New-Object System.Collections.Generic.List[object]

    foreach ($root in $roots) {
        $directories = @()
        $directories += Get-ChildItem -Path (Join-Path $root 'Inno Setup*') -Directory -ErrorAction SilentlyContinue
        $directories += Get-ChildItem -Path (Join-Path $root 'JR Software\Inno Setup*') -Directory -ErrorAction SilentlyContinue

        foreach ($directory in $directories) {
            $compiler = Join-Path $directory.FullName 'ISCC.exe'
            if (-not (Test-Path -LiteralPath $compiler)) {
                continue
            }

            $versionText = ''
            if ($directory.Name -match '(\d+(?:\.\d+)*)') {
                $versionText = $matches[1]
            }

            $version = [version]'0.0'
            if ($versionText) {
                try {
                    $version = [version]$versionText
                }
                catch {
                    $version = [version]'0.0'
                }
            }

            $candidates.Add([pscustomobject]@{
                    Path = $compiler
                    Version = $version
                })
        }
    }

    $match = $candidates |
    Sort-Object -Property @{ Expression = 'Version'; Descending = $true }, @{ Expression = 'Path'; Descending = $true } |
    Select-Object -First 1

    if (-not $match) {
        throw 'Unable to locate ISCC.exe. Add Inno Setup to PATH or set InnoCompiler in config/build-config.psd1 to an explicit path.'
    }

    return $match.Path
}

function Find-DumpBin {
    param(
        [Parameter(Mandatory)]
        [string]$VsWherePath
    )

    $dumpBinPath = & $VsWherePath -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -find '**\Hostx64\x64\dumpbin.exe' |
    Select-Object -First 1
    if (-not $dumpBinPath) {
        throw 'Unable to locate dumpbin.exe from Visual Studio.'
    }

    return $dumpBinPath
}

function Get-NormalizedVersion {
    param(
        [Parameter(Mandatory)]
        [string]$VersionText
    )

    $trimmed = $VersionText.Trim()
    if (-not $trimmed) {
        return $null
    }

    if ($trimmed -match '(\d+(?:\.\d+)+)') {
        return $matches[1]
    }

    return $trimmed
}

function Get-VersionFromHeader {
    param(
        [Parameter(Mandatory)]
        [string]$HeaderPath
    )

    if (-not (Test-Path -LiteralPath $HeaderPath)) {
        return $null
    }

    $match = Select-String -Path $HeaderPath -Pattern 'VERSION\s+"([^"]+)"' -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $match) {
        return $null
    }

    return Get-NormalizedVersion -VersionText $match.Matches[0].Groups[1].Value
}

function Get-VersionFromCMakeCache {
    param(
        [Parameter(Mandatory)]
        [string]$CMakeCachePath
    )

    if (-not (Test-Path -LiteralPath $CMakeCachePath)) {
        return $null
    }

    $match = Select-String -Path $CMakeCachePath -Pattern '^CMAKE_PROJECT_VERSION:STATIC=(.+)$' -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $match) {
        return $null
    }

    return Get-NormalizedVersion -VersionText $match.Matches[0].Groups[1].Value
}

function Resolve-AppVersion {
    param(
        [string]$VersionHeaderPath,
        [string]$CMakeCachePath
    )

    $version = $null

    if ($VersionHeaderPath) {
        $version = Get-VersionFromHeader -HeaderPath $VersionHeaderPath
    }

    if (-not $version -and $CMakeCachePath) {
        $version = Get-VersionFromCMakeCache -CMakeCachePath $CMakeCachePath
    }

    if (-not $version) {
        throw 'Unable to determine AppVersion from Craft build outputs. Set VersionHeaderPath/CMakeCachePath in config/build-config.psd1 or update the build metadata source.'
    }

    return $version
}

function New-CleanDirectory {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    if ((Test-Path -LiteralPath $Path) -and $PSCmdlet.ShouldProcess($Path, 'Remove directory tree')) {
        Remove-Item -LiteralPath $Path -Recurse -Force
    }

    New-Item -Path $Path -ItemType Directory -Force | Out-Null
}

function Invoke-CraftBuild {
    param(
        [Parameter(Mandatory)]
        [string[]]$Packages,
        [switch]$IgnoreInstalled
    )

    & {
        param($Packages, $IgnoreInstalled)

        Set-StrictMode -Off

        foreach ($package in $Packages) {
            Write-Step "Building $package with Craft"
            $craftArgs = @('--no-cache')
            if ($IgnoreInstalled) {
                $craftArgs += '--ignoreInstalled'
            }
            $craftArgs += $package
            & craft @craftArgs
            if ($LASTEXITCODE -ne 0) {
                throw "Craft build failed for package: $package"
            }
        }
    } $Packages $IgnoreInstalled
}

function Copy-RequiredFileSet {
    param(
        [Parameter(Mandatory)]
        [string]$SourceDirectory,
        [Parameter(Mandatory)]
        [string[]]$Files,
        [Parameter(Mandatory)]
        [string]$DestinationDirectory
    )

    Assert-PathExistence -Path $SourceDirectory -Label 'Source directory'

    foreach ($file in $Files) {
        $matchedItems = @(Get-ChildItem -Path $SourceDirectory -Filter $file -File -ErrorAction SilentlyContinue)
        if (-not $matchedItems) {
            throw "Required file not found in ${SourceDirectory}: $file"
        }

        foreach ($match in $matchedItems) {
            Copy-Item -LiteralPath $match.FullName -Destination $DestinationDirectory -Force
        }
    }
}

function Test-SystemDependencyName {
    param(
        [Parameter(Mandatory)]
        [string]$Name
    )

    $normalizedName = $Name.ToLowerInvariant()
    foreach ($pattern in @(
            'api-ms-win-*'
            'kernel32.dll'
            'msvcp*.dll'
            'vcruntime*.dll'
        )) {
        if ($normalizedName -like $pattern) {
            return $true
        }
    }

    return $false
}

function Find-SystemDependencyPath {
    param(
        [Parameter(Mandatory)]
        [string]$Name
    )

    foreach ($directory in @(
            (Join-Path $env:windir 'System32')
            (Join-Path $env:windir 'SysWOW64')
        )) {
        if (-not $directory) {
            continue
        }

        $candidate = Join-Path $directory $Name
        if (Test-Path -LiteralPath $candidate) {
            return $candidate
        }
    }

    return $null
}

function Get-BinaryDependency {
    param(
        [Parameter(Mandatory)]
        [string]$BinaryPath,
        [Parameter(Mandatory)]
        [string]$DumpBinPath
    )

    $output = & $DumpBinPath /nologo /dependents $BinaryPath
    if ($LASTEXITCODE -ne 0) {
        throw "dumpbin failed while reading dependencies for $BinaryPath"
    }

    $dependencies = New-Object System.Collections.Generic.List[string]
    $inDependencies = $false

    foreach ($line in $output) {
        if (-not $inDependencies) {
            if ($line -match '^\s*Image has the following dependencies:\s*$') {
                $inDependencies = $true
            }

            continue
        }

        if ($line -match '^\s*$') {
            if ($dependencies.Count -eq 0) {
                continue
            }

            break
        }

        if ($line -match '^\s+([A-Za-z0-9._-]+\.dll)\s*$') {
            $dependencies.Add($matches[1])
        }
    }

    return $dependencies
}

function Copy-GraphvizRuntime {
    param(
        [Parameter(Mandatory)]
        [string]$GraphvizBin,
        [Parameter(Mandatory)]
        [string]$DumpBinPath,
        [Parameter(Mandatory)]
        [string[]]$Roots,
        [Parameter(Mandatory)]
        [string]$DestinationDirectory
    )

    Assert-PathExistence -Path $GraphvizBin -Label 'Graphviz bin directory'
    Assert-PathExistence -Path $DumpBinPath -Label 'dumpbin.exe'

    $filesToCopy = New-Object 'System.Collections.Generic.Dictionary[string,System.IO.FileInfo]' ([System.StringComparer]::OrdinalIgnoreCase)
    $pending = New-Object System.Collections.Generic.Queue[System.IO.FileInfo]

    foreach ($root in $Roots) {
        $rootMatches = @(Get-ChildItem -Path $GraphvizBin -Filter $root -File -ErrorAction SilentlyContinue)
        if (-not $rootMatches) {
            throw "Required Graphviz runtime file not found in ${GraphvizBin}: $root"
        }

        foreach ($match in $rootMatches) {
            if (-not $filesToCopy.ContainsKey($match.FullName)) {
                $filesToCopy[$match.FullName] = $match
                $pending.Enqueue($match)
            }
        }
    }

    while ($pending.Count -gt 0) {
        $current = $pending.Dequeue()
        foreach ($dependencyName in Get-BinaryDependency -BinaryPath $current.FullName -DumpBinPath $DumpBinPath) {
            if (Test-SystemDependencyName -Name $dependencyName) {
                continue
            }

            $dependencyPath = Join-Path $GraphvizBin $dependencyName
            if (-not (Test-Path -LiteralPath $dependencyPath)) {
                if (Find-SystemDependencyPath -Name $dependencyName) {
                    continue
                }

                throw "Required Graphviz dependency not found in ${GraphvizBin}: $dependencyName"
            }

            if (-not $filesToCopy.ContainsKey($dependencyPath)) {
                $dependencyFile = Get-Item -LiteralPath $dependencyPath
                $filesToCopy[$dependencyPath] = $dependencyFile
                $pending.Enqueue($dependencyFile)
            }
        }
    }

    foreach ($file in $filesToCopy.Values | Sort-Object -Property FullName) {
        Copy-Item -LiteralPath $file.FullName -Destination $DestinationDirectory -Force
    }
}

function Set-ExecutableIcon {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [string]$RcEdit,
        [Parameter(Mandatory)]
        [string]$ExecutablePath,
        [Parameter(Mandatory)]
        [string]$IconPath
    )


    if ($PSCmdlet.ShouldProcess($ExecutablePath, 'Set executable icon')) {
        & $RcEdit $ExecutablePath --set-icon $IconPath
        if ($LASTEXITCODE -ne 0) {
            throw "rcedit failed while updating executable icon."
        }
    }
}

function Invoke-WinDeployQt {
    param(
        [Parameter(Mandatory)]
        [string]$WinDeployQtPath,
        [Parameter(Mandatory)]
        [string]$ExecutablePath
    )

    & $WinDeployQtPath $ExecutablePath
    if ($LASTEXITCODE -ne 0) {
        throw "windeployqt failed for $ExecutablePath"
    }
}

function Write-TemplateFile {
    param(
        [Parameter(Mandatory)]
        [string]$TemplatePath,
        [Parameter(Mandatory)]
        [string]$DestinationPath,
        [Parameter(Mandatory)]
        [hashtable]$Values
    )

    $content = Get-Content -LiteralPath $TemplatePath -Raw

    foreach ($key in $Values.Keys) {
        $placeholder = "{{${key}}}"
        $replacement = [string]$Values[$key]
        $content = $content.Replace($placeholder, $replacement)
    }

    $destinationDir = Split-Path -Path $DestinationPath -Parent
    New-Item -Path $destinationDir -ItemType Directory -Force | Out-Null
    Set-Content -LiteralPath $DestinationPath -Value $content -Encoding UTF8
}

function Invoke-InnoSetup {
    param(
        [Parameter(Mandatory)]
        [string]$CompilerPath,
        [Parameter(Mandatory)]
        [string]$IssPath
    )

    & $CompilerPath $IssPath
    if ($LASTEXITCODE -ne 0) {
        throw "Inno Setup compilation failed."
    }
}
