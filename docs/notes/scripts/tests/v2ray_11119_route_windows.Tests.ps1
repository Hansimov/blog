# Offline with Windows PowerShell 5.1 and Pester 3+.
# Invoke-Pester docs/notes/scripts/tests/v2ray_11119_route_windows.Tests.ps1
. (Join-Path $PSScriptRoot '..\v2ray_11119_route_windows.ps1')

function New-FakeProcess([int]$Number) {
    $p = [pscustomobject]@{Id=$Number; HasExited=$false}
    $p | Add-Member ScriptMethod Dispose {}
    $p
}

Describe 'Windows 11119 route config' {
    It 'round trips relay to direct without losing the untagged default or unrelated fields' {
        $raw = '{"inbounds":[{"port":11118},{"port":11119}],"outbounds":[{"protocol":"vmess","settings":{"vnext":[{"address":"example.invalid","port":443}]}},{"protocol":"freedom","tag":"private"},{"protocol":"blackhole"}],"routing":{"rules":[{"ip":["geoip:private"],"outboundTag":"private"}]}}'
        $relay = Get-RequestedConfig (ConvertFrom-Json $raw) 'relay'
        $relay.outbounds.Count | Should Be 4
        $relay.outbounds[0].proxySettings.tag | Should Be $RouteTag
        $relay.outbounds[3].settings.servers[0].port | Should Be 11111
        $again = Get-RequestedConfig $relay 'relay'
        $again.outbounds.Count | Should Be 4
        $direct = Get-RequestedConfig $again 'direct'
        (ConvertTo-Json $direct -Depth 100 -Compress) | Should Be $raw
    }
    It 'refuses an existing foreign detour' {
        $cfg = ConvertFrom-Json '{"outbounds":[{"protocol":"vmess","proxySettings":{"tag":"custom"}}]}'
        { Get-RequestedConfig $cfg 'direct' } | Should Throw
    }
    It 'refuses to remove an outbound in use by another rule' {
        $cfg = ConvertFrom-Json '{"outbounds":[{"protocol":"vmess"}],"routing":{"rules":[{"outboundTag":"via-local-v2ray-http-11111"}]}}'
        $cfg = Get-RequestedConfig $cfg 'relay'
        { Get-RequestedConfig $cfg 'direct' } | Should Throw
    }
    It 'creates an owner-only ACL before writing secrets' {
        $dir = New-PrivateDirectory $TestDrive
        $f = Join-Path $dir 'test.txt'
        [IO.File]::WriteAllText($f,'dummy')
        (Get-Acl -LiteralPath $dir).AreAccessRulesProtected | Should Be $true
        $rules = (Get-Acl -LiteralPath $f).GetAccessRules($true,$true,[Security.Principal.SecurityIdentifier])
        $rules.Count | Should Be 1
        ($rules[0].IdentityReference -eq [Security.Principal.WindowsIdentity]::GetCurrent().User) | Should Be $true
    }
}

Describe 'Windows 11119 production rollback' {
    BeforeEach {
        $ConfigPath = Join-Path $TestDrive 'config_vmiss.json'
        $previous = [byte[]](239,187,191,123,125,13,10)
        $changed = [Text.Encoding]::UTF8.GetBytes('{"test":true}')
        [IO.File]::WriteAllBytes($ConfigPath,$previous)
        $old = New-FakeProcess 123
        $new = New-FakeProcess 456
        $script:starts = 0
        $script:checks = 0
        Mock Get-LiveInstance { $old }
        Mock New-PrivateDirectory { $TestDrive }
        Mock Start-LiveInstance { $script:starts++; New-FakeProcess (500 + $script:starts) }
        Mock Stop-Instance { $Process.HasExited=$true }
        Mock Wait-Instance {}
        Mock Test-RouteHealth { $script:checks++ }
    }
    It 'installs a candidate and saves the original bytes' {
        $notice = (Switch-LiveRoute $previous $changed $TestDrive 123 6>&1 | Out-String).Trim()
        ($notice -eq ('Private backup: %LOCALAPPDATA%\{0}\config_vmiss.json.bak' -f [IO.Path]::GetFileName($TestDrive))) | Should Be $true
        [Convert]::ToBase64String([IO.File]::ReadAllBytes($ConfigPath)) | Should Be ([Convert]::ToBase64String($changed))
        [Convert]::ToBase64String([IO.File]::ReadAllBytes((Join-Path $TestDrive 'config_vmiss.json.bak'))) | Should Be ([Convert]::ToBase64String($previous))
        $script:starts | Should Be 1
        $script:checks | Should Be 1
    }
    It 'restores the byte-exact previous config and starts it after a failed upload' {
        Mock Test-RouteHealth { $script:checks++; if ($script:checks -eq 1) { Stop-RouteAction 'Synthetic upload failure.' } }
        { Switch-LiveRoute $previous $changed $TestDrive 123 } | Should Throw 'Previous config and route restored'
        [Convert]::ToBase64String([IO.File]::ReadAllBytes($ConfigPath)) | Should Be ([Convert]::ToBase64String($previous))
        $script:starts | Should Be 2
        $script:checks | Should Be 2
    }
    It 'recovers when the candidate process cannot be launched' {
        Mock Start-LiveInstance { $script:starts++; if ($script:starts -eq 1) { Stop-RouteAction 'Launch failed.' }; $new }
        { Switch-LiveRoute $previous $changed $TestDrive 123 } | Should Throw 'Previous config and route restored'
        [Convert]::ToBase64String([IO.File]::ReadAllBytes($ConfigPath)) | Should Be ([Convert]::ToBase64String($previous))
        $script:starts | Should Be 2
        $script:checks | Should Be 1
    }
    It 'refuses to overwrite a concurrent edit' {
        [IO.File]::WriteAllBytes($ConfigPath,$changed)
        { Switch-LiveRoute $previous $changed $TestDrive 123 } | Should Throw 'config or listener changed'
        $script:starts | Should Be 0
        Assert-MockCalled Stop-Instance -Times 0 -Scope It
    }
    It 'restarts the managed service and rolls back through SCM after a failed upload' {
        $path = 'fixture-wrapper'
        $old | Add-Member NoteProperty RouteServicePath $path
        Mock Restart-ManagedRoute { $script:starts++ }
        Mock Test-RouteHealth { $script:checks++; if ($script:checks -eq 1) { Stop-RouteAction 'Upload failed.' } }
        { Switch-LiveRoute $previous $changed $TestDrive 123 $path } | Should Throw 'Previous config and route restored'
        [Convert]::ToBase64String([IO.File]::ReadAllBytes($ConfigPath)) | Should Be ([Convert]::ToBase64String($previous))
        Assert-MockCalled Restart-ManagedRoute -Times 2 -Exactly -Scope It
        Assert-MockCalled Stop-Instance -Times 0 -Exactly -Scope It
        Assert-MockCalled Start-LiveInstance -Times 0 -Exactly -Scope It
    }
    It 'refuses a change of management during preflight' {
        { Switch-LiveRoute $previous $changed $TestDrive 123 'fixture-wrapper' } | Should Throw 'config or listener changed'
        Assert-MockCalled New-PrivateDirectory -Times 0 -Scope It
    }
}

Describe 'Windows service listener ownership' {
    BeforeEach {
        $install = Join-Path $TestDrive 'service fixture'
        $binary = Join-Path $install 'v2ray.exe'
        $config = Join-Path $install 'config_vmiss.json'
        $wrapperPath = Join-Path $install 'V2Ray11119.exe'
        $created = [datetime]'2020-01-01T00:00:00'
        $child = [pscustomobject]@{ExecutablePath=$binary; CommandLine=('"'+$binary+'" run --config="'+$config+'"')
            ParentProcessId=200; CreationDate=$created.AddSeconds(1)}
        $wrapper = [pscustomobject]@{Name='V2Ray11119.exe'; ExecutablePath=$wrapperPath; CreationDate=$created}
        $service = [pscustomobject]@{Name='V2Ray11119'; State='Running'; ProcessId=200; PathName=('"'+$wrapperPath+'"')}
        $front = [pscustomobject]@{Name='V2Ray11111'; State='Stopped'; ProcessId=0; PathName=''}
        Mock Get-CimInstance {
            if ($ClassName -eq 'Win32_Service') { return @($service,$front) }
            $wrapper
        }
        Mock Get-ListenerOwner { 0 }
    }
    It 'checks service PID, wrapper image, and absolute V2Ray config' {
        (Get-ServiceBinding $child $install) | Should Be $service.PathName
        $child.CommandLine = ('"'+$binary+'" run "--config='+$config+'"')
        (Get-ServiceBinding $child $install) | Should Be $service.PathName
        $child.CommandLine = ('"'+$binary+'" run --config=some-other.json')
        { Get-ServiceBinding $child $install } | Should Throw 'do not match'
    }
    It 'detects mixed mode, a second owner on a stopped front service, and a reused wrapper PID' {
        $child.ParentProcessId = 666
        { Get-ServiceBinding $child $install } | Should Throw 'do not match'
        $child.ParentProcessId = 200
        $wrapper.CreationDate = $child.CreationDate.AddSeconds(2)
        { Get-ServiceBinding $child $install } | Should Throw 'verify the WinSW wrapper'
        $wrapper.CreationDate = $created
        Mock Get-ListenerOwner { 777 }
        { Get-ServiceBinding $child $install } | Should Throw 'mixed management'
    }
    It 'checks the paired front listener belongs to its own registered wrapper' {
        $front.State='Running'
        $front.ProcessId=333
        Mock Get-ListenerOwner { 811 }
        { Get-ServiceBinding $child $install } | Should Throw 'do not match'
        $frontExe = Join-Path $install 'V2Ray11111.exe'
        $front.PathName = '"'+$frontExe+'"'
        $frontWrapper = [pscustomobject]@{Name='V2Ray11111.exe'; ExecutablePath=$frontExe; CreationDate=$created}
        $frontChild = [pscustomobject]@{ParentProcessId=333; CreationDate=$created.AddSeconds(1); ExecutablePath=$binary
            CommandLine=('"'+$binary+'" run --config="'+(Join-Path $install 'config.json')+'"')}
        Mock Get-CimInstance { $frontChild } -ParameterFilter { $ClassName -eq 'Win32_Process' -and $Filter -eq 'ProcessId=811' }
        Mock Get-CimInstance { $frontWrapper } -ParameterFilter { $ClassName -eq 'Win32_Process' -and $Filter -eq 'ProcessId=333' }
        (Get-ServiceBinding $child $install) | Should Be $service.PathName
    }
    It 'rejects an unrelated service owner even when there are no named V2Ray services' {
        Mock Get-CimInstance { [pscustomobject]@{Name='OtherService';ProcessId=200} }
        { Get-ServiceBinding $child $install } | Should Throw 'different Windows service'
    }
    It 'recognizes an original batch and hidden WMI after both services were disabled and stopped' {
        $windows = [Environment]::GetFolderPath('Windows')
        $batch = Join-Path $install 'launch_vmiss.bat'
        [IO.Directory]::CreateDirectory($install) | Out-Null
        [IO.File]::WriteAllText($batch,'v2ray.exe run --config=config_vmiss.json')
        foreach ($entry in $service,$front) {
            $entry.State='Stopped'
            $entry.ProcessId=0
            $entry | Add-Member NoteProperty StartMode 'Disabled'
        }
        $child | Add-Member NoteProperty ProcessId 901
        $child.CommandLine='v2ray.exe run --config=config_vmiss.json'
        $batchParent = [pscustomobject]@{Name='cmd.exe'; ExecutablePath=(Join-Path $windows 'System32\cmd.exe')
            CreationDate=$created; CommandLine=('cmd.exe /c ""'+$batch+'" "')}
        $wmi = [pscustomobject]@{Name='WmiPrvSE.exe'; ExecutablePath=(Join-Path $windows 'System32\wbem\WmiPrvSE.exe')
            CreationDate=$created}
        $frontChild = [pscustomobject]@{ParentProcessId=333; ProcessId=811; CreationDate=$created.AddSeconds(1)
            ExecutablePath=$binary; CommandLine=('"'+$binary+'" run --config="'+(Join-Path $install 'config.json')+'"')}
        Mock Get-ListenerOwner { 811 }
        Mock Get-CimInstance { $batchParent } -ParameterFilter { $ClassName -eq 'Win32_Process' -and $Filter -eq 'ProcessId=200' }
        Mock Get-CimInstance { $wmi } -ParameterFilter { $ClassName -eq 'Win32_Process' -and $Filter -eq 'ProcessId=333' }
        Mock Get-CimInstance { $frontChild } -ParameterFilter { $ClassName -eq 'Win32_Process' -and $Filter -eq 'ProcessId=811' }
        Mock Get-CimInstance {} -ParameterFilter { $ClassName -eq 'Win32_Service' -and $Filter -like 'ProcessId=*' }
        (Get-ServiceBinding $child $install) | Should BeNullOrEmpty
        $wmi.ExecutablePath = Join-Path $install 'WmiPrvSE.exe'
        { Get-ServiceBinding $child $install } | Should Throw 'unverified standalone'
        $wmi.ExecutablePath = Join-Path $windows 'System32\wbem\WmiPrvSE.exe'
        $batchParent.CreationDate = $child.CreationDate.AddSeconds(3)
        { Get-ServiceBinding $child $install } | Should Throw 'unverified standalone'
        $batchParent.CreationDate = $created
        Mock Get-CimInstance { [pscustomobject]@{Name='OtherService'} } -ParameterFilter {
            $ClassName -eq 'Win32_Service' -and $Filter -eq 'ProcessId=901 OR ProcessId=200'
        }
        { Get-ServiceBinding $child $install } | Should Throw 'another Windows service'
        $front.StartMode='Manual'
        { Get-ServiceBinding $child $install } | Should Throw 'do not match'
        $front.StartMode='Disabled'; $front.ProcessId=333
        { Get-ServiceBinding $child $install } | Should Throw 'do not match'
    }
    It 'controls only the main SCM service and verifies the new listener' {
        Mock Get-CimInstance { $service }
        Mock Get-ListenerOwner { 500 }
        $live = New-FakeProcess 500
        $live | Add-Member NoteProperty RouteServicePath $service.PathName
        Mock Get-LiveInstance { $live }
        Mock Stop-Service {}
        Mock Start-Service {}
        Restart-ManagedRoute $service.PathName
        Assert-MockCalled Stop-Service -ParameterFilter { $Name -eq 'V2Ray11119' } -Times 1 -Exactly -Scope It
        Assert-MockCalled Start-Service -ParameterFilter { $Name -eq 'V2Ray11119' } -Times 1 -Exactly -Scope It
        Assert-MockCalled Get-LiveInstance -Times 1 -Exactly -Scope It
        $service.State='Stopped'
        Restart-ManagedRoute $service.PathName
        Assert-MockCalled Stop-Service -Times 1 -Exactly -Scope It
        Assert-MockCalled Start-Service -Times 2 -Exactly -Scope It
        { Restart-ManagedRoute 'changed-wrapper' } | Should Throw 'registration changed'
        Assert-MockCalled Start-Service -Times 2 -Exactly -Scope It
    }
}
