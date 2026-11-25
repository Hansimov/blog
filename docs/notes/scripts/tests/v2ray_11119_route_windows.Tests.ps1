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
}
