Import-Module "$PSScriptRoot/../Config.psm1" -Force

function Get-WgActiveInterfaceName {
    $wgOutput = & wg 2>&1
    if ($LASTEXITCODE -ne 0 -and -not $wgOutput) {
        Write-Error "Failed to run 'wg'. Ensure wg.exe is in PATH and you're running as an appropriate user."
        exit 1
    }

    $interfaceName = $null;
    $match = [string] $wgOutput -match 'interface:\s*(\S+)';
    if ($Matches -And $Matches[1]) { 
        $interfaceName = $Matches[1];
    }

    return $interfaceName;
}

function Get-WgCurrentConfig {
    Write-Host "Reading current config..."

    $interfaceName = Get-WgActiveInterfaceName;

    if (-not $interfaceName) {
        Write-Error "Could not determine interface from active connection."
        exit 1
    }

    # Get current conf (only shows rather minimal wg conf, not wg-quick conf, so can't read too much from this)
    # This captures an array of lines for each line break
    $showconf = wg showconf $interfaceName
    if ($LASTEXITCODE -ne 0 -and -not $showconf) {
        Write-Error "Failed to run 'wg showconf $interfaceName'. Output:`n$showconf"
        exit 1
    }

    # Extract some interface values of interest
    $interfaceSection = @();
    $peersSection = @();
    $currentSection = 'interface';
    foreach ($line in $showconf) {
        if ($line -match "\[Peer\]") {
            $currentSection = 'peers';
        }
        if ($currentSection -eq 'interface') {
            $interfaceSection += $line;
        } else {
            $peersSection += $line;
        }
    }

    # Trim trailing empty lines
    while ($interfaceSection.Length -gt 0 -and [string]::IsNullOrEmpty($interfaceSection[-1])) {
        $interfaceSection = $interfaceSection[0..($interfaceSection.Length - 2)]
    }
    while ($peersSection.Length -gt 0 -and [string]::IsNullOrEmpty($peersSection[-1])) {
        $peersSection = $peersSection[0..($peersSection.Length - 2)]
    }

    $listenPort = $null;
    $privateKey = $null;
    foreach ($line in $interfaceSection) {
        if ($line -match 'PrivateKey\s*=\s*(.*)') {
            $privateKey = $Matches[1].trim();
            continue;
        }
        if ($line -match 'ListenPort\s*=\s*(.*)') {
            $listenPort = $Matches[1].trim();
            continue;
        }
    }

    # Then try to determine extra variables that would be included in wg-quick conf

    # Figure out address
    $addressWithSubnetV4 = $null
    try {
        $ip4Info = Get-NetIPAddress -InterfaceAlias $interfaceName -AddressFamily IPv4 -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($ip4Info -and $ip4Info.IPAddress) {
            $subnet4 = $ip4Info.PrefixLength;
            $addressWithSubnetV4 = $ip4Info.IPAddress + $(if ($subnet4) { "/$subnet4" } else { "" })
        }
    } catch {
        Write-Verbose "Error getting IPv4 info for $interfaceName. Not including it in the result."
    }

    $addressWithSubnetV6 = $null;
    try {
        $ip6Info = Get-NetIPAddress -InterfaceAlias $interfaceName -AddressFamily IPv6 -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($ip6Info -and $ip6Info.IPAddress) {
            $subnet6 = $ip6Info.PrefixLength;
            $addressWithSubnetV6 = $ip6Info.IPAddress + $(if ($subnet6) { "/$subnet6" } else { "" })
        }
    } catch {
        Write-Verbose "Error getting IPv6 info for $interfaceName. Not including it in the result."
    }

    $address = (@($addressWithSubnetV4, $addressWithSubnetV6) | Where-Object { $_ -ne $null }) -join ', '

    # Figure out DNS
    $dns = $null;
    try {
        $dnsResult = (Get-DnsClientServerAddress -InterfaceAlias $interfaceName).ServerAddresses;
        if ($dnsResult -and $dnsResult.Count -gt 0) {
            $dns = $dnsResult -join ','
        }
    } catch {}

    # Figure out MTU
    $mtu = $null;
    try {
        $mtuResult = Get-NetIPInterface -InterfaceAlias $interfaceName | Sort-Object AddressFamily | Select-Object NlMtu
        if ($mtuResult.Length) {
            $mtu = $mtuResult[0].NlMtu
        }
    } catch {}

    # Assemble everything
    $finalConf = $interfaceSection
    if ($address) { $finalConf += "Address = $address" }
    if ($dns) { $finalConf += "DNS = $dns" }
    if ($mtu) { $finalConf += "MTU = $mtu" }
    $finalConf += " "
    $finalConf += $peersSection

    return @{
        InterfaceName = $interfaceName
        ListenPort = $listenPort
        PrivateKey = $privateKey
        Address = $address
        DNS = $dns
        MTU = $mtu
        Config = ($finalConf -join "`n")
    }
}

function Test-WgInterfaceExists {
    param (
        [string] $interfaceName
    )

    if (Test-Path "$wgConfDir/$interfaceName.conf.dpapi" -PathType Leaf) {
        return $true;
    } else {
        return $false;
    }
}

function Backup-WgConf {
    $currentConfig = Get-WgCurrentConfig
    $interfaceName = $currentConfig.InterfaceName;
    $conf = $currentConfig.Config;

    # Save backup conf
    New-Item -ItemType Directory -Force -Path $backupDir | Out-Null
    $timestamp = Get-Timestamp
    $backupConfPath = "$backupDir/$interfaceName-$timestamp.bk.conf"
    Save-File $backupConfPath $conf

    Write-Host "Wrote config backup to: "
    Write-Host "- $backupConfPath"

    # Return current config that was backed up for convenience
    return $currentConfig
}

function Get-Timestamp {
    return Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
}

function Hide-SensitiveData {
    param (
        [string] $conf
    )
    $sanitized = $conf;
    $sanitized = $sanitized -replace '(?im)^PrivateKey\s*=\s*.+$', 'PrivateKey = (HIDDEN, use backup option to see)';
    $sanitized = $sanitized -replace '(?im)^PresharedKey\s*=\s*.+$', 'PresharedKey = (HIDDEN, use backup option to see)';
    return $sanitized
}

function Save-File {
    param (
        [string] $path,
        [string] $content
    )
    $Utf8NoBomEncoding = New-Object System.Text.UTF8Encoding $False
    [System.IO.File]::WriteAllLines($path, $content, $Utf8NoBomEncoding)
}

Export-ModuleMember -Function Get-WgActiveInterfaceName
Export-ModuleMember -Function Get-WgCurrentConfig
Export-ModuleMember -Function Test-WgInterfaceExists 
Export-ModuleMember -Function Backup-WgConf
Export-ModuleMember -Function Get-Timestamp
Export-ModuleMember -Function Hide-SensitiveData
Export-ModuleMember -Function Save-File
