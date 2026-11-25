#requires -Version 5.1
<#
.SYNOPSIS
Switch the Windows config_vmiss.json VMess outbound between direct and HTTP 11111.
.DESCRIPTION
Run with Windows PowerShell 5.1. The existing V2Ray 5 batch launcher must contain
only "v2ray.exe run --config=config_vmiss.json", with its working directory set to
the installation directory. Its Startup shortcut continues to load the same file.
The script discovers the directory from the running listener. Use -Directory to
require that the instance belongs to a particular installation.
test-direct and test-relay use a temporary loopback port. direct and relay briefly
interrupt the 11118/11119 instance. Backups are under the current user's LocalAppData.
#>
param(
    [ValidateSet('status','test-direct','test-relay','direct','relay')]
    [string]$Mode = 'status',
    [string]$Directory
)

$RouteTag = 'via-local-v2ray-http-11111'
$Utf8 = [Text.UTF8Encoding]::new($false)

function Stop-RouteAction([string]$Message) { throw "Route error: $Message" }

function New-PrivateDirectory([string]$Parent) {
    $path = Join-Path $Parent ("v2ray-11119-route-" + [guid]::NewGuid().ToString('N'))
    $acl = [Security.AccessControl.DirectorySecurity]::new()
    $acl.SetAccessRuleProtection($true, $false)
    $sid = [Security.Principal.WindowsIdentity]::GetCurrent().User
    $acl.AddAccessRule([Security.AccessControl.FileSystemAccessRule]::new(
        $sid, 'FullControl', 'ContainerInherit,ObjectInherit', 'None', 'Allow'))
    [IO.Directory]::CreateDirectory($path, $acl).FullName
}

function Get-RequestedConfig($Config, [string]$Route) {
    $out = $Config.outbounds[0]
    if ($out.protocol -cne 'vmess' -or
        ($out.streamSettings.network -and $out.streamSettings.network -cne 'tcp') -or
        ($out.streamSettings.security -and $out.streamSettings.security -cne 'none') -or
        $out.streamSettings.sockopt.dialerProxy -or $out.streamSettings.tcpSettings -or $out.mux.enabled) {
        Stop-RouteAction 'Expected the existing default raw TCP VMess outbound.'
    }
    $http = @($Config.outbounds | Where-Object tag -CEQ $RouteTag)
    $via = $out.proxySettings
    if ($null -ne $via -or $http.Count) {
        if ($via.tag -cne $RouteTag -or @($via.psobject.Properties).Count -ne 1 -or
            $http.Count -ne 1 -or $http[0].protocol -cne 'http' -or
            @($http[0].psobject.Properties).Count -ne 3 -or
            @($http[0].settings.psobject.Properties).Count -ne 1 -or
            @($http[0].settings.servers).Count -ne 1 -or
            $http[0].settings.servers[0].address -cne '127.0.0.1' -or
            $http[0].settings.servers[0].port -ne 11111 -or
            @($http[0].settings.servers[0].psobject.Properties).Count -ne 2) {
            Stop-RouteAction 'Existing detour or relay tag differs from the managed route.'
        }
        if ($Route -eq 'direct') {
            $out.psobject.Properties.Remove('proxySettings')
            $Config.outbounds = @($Config.outbounds | Where-Object { $_.tag -cne $RouteTag })
            if ((ConvertTo-Json $Config -Depth 100 -Compress).Contains('"' + $RouteTag + '"')) {
                Stop-RouteAction 'Another setting references the relay outbound.'
            }
        }
    } elseif ($Route -eq 'relay') {
        $out | Add-Member NoteProperty proxySettings ([pscustomobject]@{tag=$RouteTag})
        $Config.outbounds += [pscustomobject]@{protocol='http'; tag=$RouteTag; settings=[pscustomobject]@{
            servers=@([pscustomobject]@{address='127.0.0.1'; port=11111})}}
    }
    $Config
}

function Get-ListenerOwner([int[]]$Ports) {
    $listeners = @(Get-NetTCPConnection -LocalAddress '127.0.0.1' -State Listen -LocalPort $Ports -ErrorAction SilentlyContinue)
    $owners = @($listeners.OwningProcess | Sort-Object -Unique)
    if ($listeners.Count -eq $Ports.Count -and $owners.Count -eq 1) { return $owners[0] }
    return 0
}

function Get-LiveInstance([string]$ExpectedDirectory) {
    $owner = Get-ListenerOwner @(11118,11119)
    if (!$owner) { Stop-RouteAction 'Expected both production loopback listeners on the same process.' }
    $proc = [Diagnostics.Process]::GetProcessById($owner)
    try {
        $null = $proc.Handle  # Pin the process across discovery, CIM checks and termination.
        $binary = $proc.MainModule.FileName
        $install = [IO.Path]::GetDirectoryName($binary)
        $info = Get-CimInstance Win32_Process -Filter "ProcessId=$owner"
        if ([IO.Path]::GetFileName($binary) -ine 'v2ray.exe' -or $info.ExecutablePath -ine $binary -or
            ($ExpectedDirectory -and $ExpectedDirectory -ine $install)) {
            Stop-RouteAction 'Expected the loopback listeners to belong to the selected V2Ray installation.'
        }
        $configPath = Join-Path $install 'config_vmiss.json'
        $argsPattern = '^\s*(?:"' + [regex]::Escape($binary) + '"|v2ray\.exe)\s+run\s+'
        $relative = $info.CommandLine -match ($argsPattern + '--config=config_vmiss\.json\s*$')
        $absolute = $info.CommandLine -match ($argsPattern + '--config="' + [regex]::Escape($configPath) + '"\s*$')
        if ($relative) {
            $parent = Get-CimInstance Win32_Process -Filter "ProcessId=$($info.ParentProcessId)"
            $batch = Join-Path $install 'launch_vmiss.bat'
            $relative = ($parent.Name -ieq 'cmd.exe' -and
                $parent.CommandLine -match ('(?i)\s/c\s+""' + [regex]::Escape($batch) + '"\s*"\s*$') -and
                [IO.File]::ReadAllText($batch).Trim() -ceq 'v2ray.exe run --config=config_vmiss.json')
        }
        if ($proc.HasExited -or !($relative -or $absolute)) {
            Stop-RouteAction 'Listener owner is outside the supported config_vmiss.json launcher.'
        }
        $proc
    } catch {
        $proc.Dispose()
        throw
    }
}

function Start-LiveInstance {
    # WMI starts the replacement independently of the invoking terminal/job.
    $startup = New-CimInstance -ClassName Win32_ProcessStartup -ClientOnly -Property @{ShowWindow=[uint16]0}
    $created = Invoke-CimMethod -ClassName Win32_Process -MethodName Create -Arguments @{
        CommandLine=('"{0}" run --config="{1}"' -f $Binary,$ConfigPath)
        CurrentDirectory=$Directory; ProcessStartupInformation=$startup
    }
    if ($created.ReturnValue -ne 0) { Stop-RouteAction 'Could not launch the production instance.' }
    $proc = [Diagnostics.Process]::GetProcessById($created.ProcessId)
    $null = $proc.Handle
    $info = Get-CimInstance Win32_Process -Filter "ProcessId=$($proc.Id)"
    if ($proc.HasExited -or $info.ExecutablePath -ine $Binary -or
        $info.CommandLine -ine ('"{0}" run --config="{1}"' -f $Binary,$ConfigPath)) {
        $proc.Dispose()
        Stop-RouteAction 'The newly launched instance could not be identified.'
    }
    $proc
}

function Stop-Instance($Process) {
    if ($Process -and !$Process.HasExited) {
        $Process.Kill()
        if (!$Process.WaitForExit(5000)) { Stop-RouteAction 'Timed out stopping the selected instance.' }
    }
}

function Wait-Instance($Process, [int[]]$Ports) {
    $wait = [Diagnostics.Stopwatch]::StartNew()
    while (!$Process.HasExited -and $wait.Elapsed.TotalSeconds -lt 10) {
        if ((Get-ListenerOwner $Ports) -eq $Process.Id) { return }
        Start-Sleep -Milliseconds 100
    }
    Stop-RouteAction 'The expected instance did not acquire its listeners.'
}

function Test-RouteHealth([int]$Port, [string]$Scratch) {
    $curl = (Get-Command curl.exe -CommandType Application -ErrorAction Stop).Source
    $base = @('-q','-s','--noproxy','proxy-check.invalid','-x',"http://127.0.0.1:$Port",
        '--connect-timeout','8','--max-time','25','-o','NUL')
    $status = & $curl @base '-w' '%{response_code}' 'https://chatgpt.com/backend-api/codex/models'
    if ($LASTEXITCODE -ne 0 -or $status -ne '401') { Stop-RouteAction 'Codex models reachability check failed.' }
    $sample = Join-Path $Scratch 'synthetic-upload.bin'
    if (![IO.File]::Exists($sample)) {
        $bytes = New-Object byte[] 2400000
        $rng = [Security.Cryptography.RandomNumberGenerator]::Create()
        try { $rng.GetBytes($bytes) } finally { $rng.Dispose() }
        [IO.File]::WriteAllBytes($sample, $bytes)
    }
    $upload = & $curl @base '-H' 'Expect:' '-H' 'Content-Type: application/octet-stream' '--data-binary' ("@" + $sample) '-w' '%{response_code} %{size_upload} %{time_total}' 'https://speed.cloudflare.com/__up'
    if ($LASTEXITCODE -ne 0 -or $upload -notmatch '^200 2400000 ([0-9.]+)$') {
        Stop-RouteAction 'The 2.4 MB synthetic upload failed its 25 s check.'
    }
    Write-Host "Port $Port passed Codex reachability and uploaded 2.4 MB in $($Matches[1]) s."
}

function Test-Candidate([string]$Json, [string]$Scratch) {
    $candidate = Join-Path $Scratch 'candidate.json'
    [IO.File]::WriteAllText($candidate,$Json,$Utf8)
    Push-Location -LiteralPath $Directory
    try {
        & $Binary test -c $candidate *> $null
        if ($LASTEXITCODE -ne 0) { Stop-RouteAction 'V2Ray rejected the production candidate.' }
    } finally { Pop-Location }
    $config = ConvertFrom-Json $Json
    $loop = [Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback,0)
    $loop.Start()
    try { $port = $loop.LocalEndpoint.Port } finally { $loop.Stop() }
    $probeConfig = @{log=@{loglevel='none'}; outbounds=$config.outbounds
        inbounds=@(@{listen='127.0.0.1';port=$port;protocol='http';settings=@{}})}
    $path = Join-Path $Scratch 'probe.json'
    [IO.File]::WriteAllText($path,(ConvertTo-Json $probeConfig -Depth 100),$Utf8)
    $proc = Start-Process -FilePath $Binary -ArgumentList ('run -c "' + $path + '"') -WorkingDirectory $Directory -WindowStyle Hidden -PassThru
    try {
        Wait-Instance $proc @($port)
        Test-RouteHealth $port $Scratch
    } finally { Stop-Instance $proc; $proc.Dispose() }
}

function Install-Bytes([byte[]]$Bytes, [string]$Scratch) {
    $stage = Join-Path $Scratch 'install.json'
    [IO.File]::WriteAllBytes($stage,$Bytes)
    # ReplaceFile retains the destination file's ACL. Scratch resides on the same volume.
    [IO.File]::Replace($stage,$ConfigPath,[System.Management.Automation.Language.NullString]::Value)
}

function Switch-LiveRoute([byte[]]$Original, [byte[]]$Changed, [string]$Scratch, [int]$ExpectedOwner) {
    $proc = Get-LiveInstance $Directory
    if ($proc.Id -ne $ExpectedOwner -or ![Collections.StructuralComparisons]::StructuralEqualityComparer.Equals(
        [IO.File]::ReadAllBytes($ConfigPath), $Original)) {
        $proc.Dispose()
        Stop-RouteAction 'The config or listener changed during preflight. Run the command again.'
    }
    $backupDirectory = New-PrivateDirectory $env:LOCALAPPDATA
    $backup = Join-Path $backupDirectory 'config_vmiss.json.bak'
    [IO.File]::WriteAllBytes($backup,$Original)
    Write-Host ('Private backup: %LOCALAPPDATA%\{0}\config_vmiss.json.bak' -f [IO.Path]::GetFileName($backupDirectory))
    $replacement = $null
    try {
        Install-Bytes $Changed $Scratch
        try {
            Stop-Instance $proc
            $replacement = Start-LiveInstance
            Wait-Instance $replacement @(11118,11119)
            Test-RouteHealth 11119 $Scratch
        } catch {
            $cause = $_.Exception.Message
            Install-Bytes $Original $Scratch
            if ($replacement) { Stop-Instance $replacement }
            if ($proc.HasExited) {
                $restored = Start-LiveInstance
            } else { $restored = $proc }
            try {
                Wait-Instance $restored @(11118,11119)
                try { Test-RouteHealth 11119 $Scratch } catch {
                    Stop-RouteAction 'Previous config and listeners restored. The previous route failed its network check.'
                }
            } finally { if ($restored -ne $proc) { $restored.Dispose() } }
            if (!$cause.StartsWith('Route error:')) { $cause = 'Production restart or check failed.' }
            Stop-RouteAction "Previous config and route restored. $cause"
        }
    } finally {
        if ($replacement) { $replacement.Dispose() }
        $proc.Dispose()
    }
}

function Invoke-WindowsRoute {
    $mutex = [Threading.Mutex]::new($false,'Global\V2Ray-Windows-11119-Route')
    $locked = $false
    $scratch = $null
    try {
        try { $locked = $mutex.WaitOne(0) } catch [Threading.AbandonedMutexException] { $locked=$true }
        if (!$locked) { Stop-RouteAction 'Another route check or change is in progress.' }
        if ($Directory) { $Directory = (Get-Item -LiteralPath $Directory -ErrorAction Stop).FullName }
        $proc = Get-LiveInstance $Directory
        try {
            $owner = $proc.Id
            $Binary = $proc.MainModule.FileName
            $Directory = [IO.Path]::GetDirectoryName($Binary)
            $ConfigPath = Join-Path $Directory 'config_vmiss.json'
        } finally { $proc.Dispose() }
        $raw = [IO.File]::ReadAllBytes($ConfigPath)
        $config = $Utf8.GetString($raw).TrimStart([char]0xfeff) | ConvertFrom-Json
        foreach ($item in @(@{p=11118;s='socks'},@{p=11119;s='http'})) {
            if (@($config.inbounds | Where-Object { $_.port -eq $item.p -and $_.protocol -eq $item.s -and $_.listen -eq '127.0.0.1' }).Count -ne 1) {
                Stop-RouteAction 'Expected loopback SOCKS 11118 and HTTP 11119 in the selected config.'
            }
        }
        $originalMode = if ($config.outbounds[0].proxySettings) { 'relay' } else { 'direct' }
        $route = if ($Mode -eq 'status') { $originalMode } else { $Mode.Replace('test-','') }
        $changed = Get-RequestedConfig $config $route
        Write-Host "Configured route: $originalMode. Listener PID: $owner."
        if ($Mode -eq 'status') { return }
        $version = & $Binary version | Select-Object -First 1
        if ($version -notmatch '^V2Ray 5\.') { Stop-RouteAction 'This helper requires V2Ray 5.' }
        $scratch = New-PrivateDirectory $Directory
        $json = (ConvertTo-Json $changed -Depth 100) + [Environment]::NewLine
        Test-Candidate $json $scratch
        if ($Mode -like 'test-*') { return }
        if ($route -eq $originalMode) {
            Test-RouteHealth 11119 $scratch
            Write-Host 'Already configured; no restart required.'
            return
        }
        Switch-LiveRoute $raw ($Utf8.GetBytes($json)) $scratch $owner
        Write-Host "Active route: $route."
    } finally {
        if ($scratch) {
            foreach ($name in 'candidate.json','probe.json','synthetic-upload.bin','install.json') {
                [IO.File]::Delete((Join-Path $scratch $name))
            }
            [IO.Directory]::Delete($scratch)
        }
        if ($locked) { $mutex.ReleaseMutex() }
        $mutex.Dispose()
    }
}

if ($MyInvocation.InvocationName -ne '.') {
    $ErrorActionPreference = 'Stop'
    try { Invoke-WindowsRoute } catch {
        $message = $_.Exception.Message
        if (!$message.StartsWith('Route error:')) { $message = 'Route action failed (' + $_.Exception.GetType().Name + ').' }
        [Console]::Error.WriteLine($message)
        exit 1
    }
}
