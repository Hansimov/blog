# Install for the current Windows user. Run from any directory with Windows PowerShell 5.1.
#requires -Version 5.1
[CmdletBinding()]
param([switch]$RemoteSsh)

$ErrorActionPreference = 'Stop'
$store = Join-Path $env:LOCALAPPDATA 'vscode-codex-account'
$manager = Join-Path $store 'account.py'
$sourceManager = Join-Path $PSScriptRoot 'account.py'
$sourceLauncher = Join-Path $PSScriptRoot 'Launcher.cs'
$utf8 = [Text.UTF8Encoding]::new($false)

function Find-Python {
    foreach ($name in 'python.exe', 'py.exe') {
        foreach ($application in @(Get-Command $name -CommandType Application -All -ErrorAction SilentlyContinue)) {
            $options = @()
            if ($name -eq 'py.exe') { $options = @('-3') }
            try {
                $path = & $application.Source @options -I -c 'import sys; assert sys.version_info >= (3,9); print(sys.executable)' 2>$null
                if ($LASTEXITCODE -eq 0 -and $path -and (Test-Path -LiteralPath $path -PathType Leaf)) {
                    return [IO.Path]::GetFullPath($path)
                }
            } catch { continue }
        }
    }
    throw 'Python 3.9 or newer is required (python.exe or py.exe -3).'
}

function Test-PathEntry([string]$entries, [string]$path) {
    foreach ($entry in ($entries -split ';')) {
        $expanded = [Environment]::ExpandEnvironmentVariables($entry.Trim().Trim('"')).TrimEnd('\')
        if ($expanded -eq $path.TrimEnd('\')) { return $true }
    }
    return $false
}

function Write-InstalledFile([string]$destination, [byte[]]$bytes) {
    $temporary = "$destination.$([Guid]::NewGuid().ToString('N')).tmp"
    $backup = "$temporary.old"
    try {
        [IO.File]::WriteAllBytes($temporary, $bytes)
        if ([IO.File]::Exists($destination)) {
            [IO.File]::Replace($temporary, $destination, $backup)
        } else {
            [IO.File]::Move($temporary, $destination)
        }
    } finally {
        foreach ($file in $temporary, $backup) { [IO.File]::Delete($file) }
    }
}

function Get-Launcher([string]$compiler) {
    $digest = (Get-FileHash -Algorithm SHA256 -LiteralPath $sourceLauncher).Hash.ToLowerInvariant()
    $launcher = Join-Path $store 'extension-launcher.exe'
    $stamp = Join-Path $store 'extension-launcher.sha256'
    if ([IO.File]::Exists($launcher)) {
        if ([IO.File]::Exists($stamp) -and [IO.File]::ReadAllText($stamp).Trim() -eq $digest) {
            return $launcher
        }
        # A running extension may hold the old EXE open until its window reloads.
        $launcher = Join-Path $store "extension-launcher-$digest.exe"
        if ([IO.File]::Exists($launcher)) { return $launcher }
    }
    $temporary = Join-Path $store ("build-" + [Guid]::NewGuid().ToString('N') + '.exe')
    try {
        $messages = & $compiler '/nologo' '/target:exe' '/optimize+' '/reference:System.Web.Extensions.dll' "/out:$temporary" $sourceLauncher
        if ($LASTEXITCODE -ne 0) { throw ("Launcher compilation failed. " + ($messages -join [Environment]::NewLine)) }
        [IO.File]::Move($temporary, $launcher)
        if ([IO.Path]::GetFileName($launcher) -eq 'extension-launcher.exe') {
            Write-InstalledFile $stamp ($utf8.GetBytes($digest))
        }
        return $launcher
    } finally {
        [IO.File]::Delete($temporary)
    }
}

function Install-PathLauncher([string]$compiler, [string]$binDir) {
    $source = Join-Path $PSScriptRoot 'PathLauncher.cs'
    $digest = (Get-FileHash -Algorithm SHA256 -LiteralPath $source).Hash.ToLowerInvariant()
    $compiled = Join-Path $store "path-command-$digest.exe"
    $destination = Join-Path $binDir 'vscodex-app-server.exe'
    foreach ($command in @(Get-Command vscodex-app-server -All -ErrorAction SilentlyContinue)) {
        if ($command.CommandType -ne 'Application' -or $command.Source -ne $destination) {
            throw 'Another vscodex-app-server command is on PATH. Resolve the conflict before installing.'
        }
    }
    if (![IO.File]::Exists($compiled)) {
        $temporary = Join-Path $store ("build-" + [Guid]::NewGuid().ToString('N') + '.exe')
        try {
            $messages = & $compiler '/nologo' '/target:exe' '/optimize+' "/out:$temporary" $source
            if ($LASTEXITCODE -ne 0) { throw ("PATH launcher compilation failed. " + ($messages -join [Environment]::NewLine)) }
            [IO.File]::Move($temporary, $compiled)
        } finally {
            [IO.File]::Delete($temporary)
        }
    }
    [void][IO.Directory]::CreateDirectory($binDir)
    if (![IO.File]::Exists($destination)) {
        [IO.File]::Copy($compiled, $destination, $false)
        return
    }
    $installedHash = (Get-FileHash -LiteralPath $destination).Hash
    if ($installedHash -eq (Get-FileHash -LiteralPath $compiled).Hash) { return }
    $known = Get-ChildItem -LiteralPath $store -Filter 'path-command-*.exe' -File |
        Where-Object { $_.Name -match '^path-command-[a-f0-9]{64}\.exe$' -and (Get-FileHash -LiteralPath $_.FullName).Hash -eq $installedHash } |
        Select-Object -First 1
    if (!$known) { throw 'The existing vscodex-app-server executable is not managed by this installer.' }
    Write-InstalledFile $destination ([IO.File]::ReadAllBytes($compiled))
}

if (!(Test-Path -LiteralPath $sourceManager -PathType Leaf) -or !(Test-Path -LiteralPath $sourceLauncher -PathType Leaf)) {
    throw 'Keep install.ps1, account.py and Launcher.cs in the same source directory.'
}
$python = Find-Python
$compiler = @('Framework64', 'Framework') | ForEach-Object {
    Join-Path $env:windir "Microsoft.NET\$_\v4.0.30319\csc.exe"
} | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } | Select-Object -First 1
if (!$compiler) { throw 'The .NET Framework 4.x C# compiler (csc.exe) is required.' }

$npmBin = Join-Path $env:APPDATA 'npm'
$ownBin = Join-Path $store 'bin'
$userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
$shimDir = $ownBin
if ((Test-PathEntry $userPath $npmBin) -or (Test-PathEntry $env:Path $npmBin)) { $shimDir = $npmBin }
# The ASCII command works with every console code page. run.ps1 stores the absolute interpreter path.
$shimText = (@(
    '@echo off'
    '@rem Managed by vscode-codex-account'
    '@setlocal DisableDelayedExpansion'
    '@"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%LOCALAPPDATA%\vscode-codex-account\run.ps1" %*'
    '@exit /b %errorlevel%'
) -join "`r`n") + "`r`n"
$locations = @($ownBin, $npmBin | ForEach-Object { Join-Path $_ 'vscodex.cmd' })
foreach ($command in @(Get-Command vscodex -All -ErrorAction SilentlyContinue)) {
    if ($command.CommandType -ne 'Application' -or $command.Source -notin $locations) {
        throw 'Another vscodex command is on PATH. Move or rename it before installing.'
    }
    $shimDir = Split-Path -Parent $command.Source
}
$shim = Join-Path $shimDir 'vscodex.cmd'
foreach ($location in $locations) {
    if ((Test-Path -LiteralPath $location) -and [IO.File]::ReadAllText($location) -cne $shimText) {
        throw "An existing command at $location is not managed by this installer."
    }
}

# Assign the DACL at creation so credentials are private from the first write.
$security = [Security.AccessControl.DirectorySecurity]::new()
$security.SetAccessRuleProtection($true, $false)
$user = [Security.Principal.WindowsIdentity]::GetCurrent().User
$system = [Security.Principal.SecurityIdentifier]::new('S-1-5-18')
foreach ($sid in $user, $system) {
    $rule = [Security.AccessControl.FileSystemAccessRule]::new(
        $sid, 'FullControl', 'ContainerInherit, ObjectInherit', 'None', 'Allow')
    $security.AddAccessRule($rule)
}
if ((Test-Path -LiteralPath $store) -and ((Get-Item -Force -LiteralPath $store).Attributes -band [IO.FileAttributes]::ReparsePoint)) {
    throw 'The installation directory cannot be a junction or symbolic link.'
}
$directory = [IO.Directory]::CreateDirectory($store, $security)
$directory.SetAccessControl($security)
$lockPath = Join-Path $store 'install.lock'
$lock = [IO.File]::Open($lockPath, 'OpenOrCreate', 'ReadWrite', 'None')
try {
    $launcher = Get-Launcher $compiler
    foreach ($scriptName in 'release_channel.py', 'thread_control.py', 'thread_lookup.py', 'backend.py', 'history.py', 'account.py') {
        Write-InstalledFile (Join-Path $store $scriptName) ([IO.File]::ReadAllBytes((Join-Path $PSScriptRoot $scriptName)))
    }
    Write-InstalledFile (Join-Path $store 'python-path') ($utf8.GetBytes($python))
    $runScript = "& '" + $python.Replace("'", "''") + "' -I (Join-Path `$PSScriptRoot 'account.py') @args`r`nexit `$LASTEXITCODE`r`n"
    $bom = [Text.UTF8Encoding]::new($true).GetPreamble()
    Write-InstalledFile (Join-Path $store 'run.ps1') ([byte[]]($bom + $utf8.GetBytes($runScript)))
    $configureArgs = @('configure', $launcher)
    if ($RemoteSsh -or [IO.File]::Exists((Join-Path $store 'path-launcher-target'))) {
        Install-PathLauncher $compiler $shimDir
        $configureArgs += '--remote-ssh'
    }
    & $python -I $manager @configureArgs
    if ($LASTEXITCODE -ne 0) { throw 'VS Code configuration failed. Correct the reported problem and rerun the installer.' }

    [void][IO.Directory]::CreateDirectory($shimDir)
    if (![IO.File]::Exists($shim)) {
        # Publish only if no file has appeared since the ownership check.
        $stream = [IO.File]::Open($shim, 'CreateNew', 'Write', 'None')
        try {
            $shimBytes = [Text.Encoding]::ASCII.GetBytes($shimText)
            $stream.Write($shimBytes, 0, $shimBytes.Length)
        } finally { $stream.Dispose() }
    }
    if ($shimDir -eq $ownBin -and !(Test-PathEntry $userPath $ownBin)) {
        # Preserve expandable tokens such as %USERPROFILE% in the user's existing PATH.
        $environmentKey = [Microsoft.Win32.Registry]::CurrentUser.CreateSubKey('Environment')
        try {
            $raw = [string]$environmentKey.GetValue('Path', '', 'DoNotExpandEnvironmentNames')
            if (!(Test-PathEntry $raw $ownBin)) {
                $updated = @($raw.TrimEnd(';'), $ownBin | Where-Object { $_ }) -join ';'
                $environmentKey.SetValue('Path', $updated, 'ExpandString')
            }
        } finally { $environmentKey.Dispose() }
        Write-Host 'User PATH updated. Restart the sign-in session if a newly opened terminal does not see vscodex.'
    }
    if (!(Test-PathEntry $env:Path $shimDir)) { $env:Path = $env:Path.TrimEnd(';') + ';' + $shimDir }
    Write-Host "Installed $shim"
} finally { $lock.Dispose() }
