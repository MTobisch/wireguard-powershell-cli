Import-Module "$PSScriptRoot/../Config.psm1" -Force
Import-Module "$PSScriptRoot/WgUtils.psm1" -Force
Import-Module "$PSScriptRoot/SysUtils.psm1" -Force

function Show-WgConnections {
    $activeInterfaceName = Get-WgActiveInterfaceName;

    Write-Host $wgConfDir;
    Write-Host "";
    Write-Host "Available Wireguard configs:"
    Write-Host "----------------------------"
    $confFiles = Get-ChildItem -Path $wgConfDir
    foreach ($confFile in $confFiles) {
        if ($confFile.extension -eq '.dpapi') {
            $interfaceName = $confFile.baseName.Replace('.conf', '');
            if ($activeInterfaceName -eq $interfaceName) {
                Write-Host -ForegroundColor Green ($interfaceName = $interfaceName + ' (active)');
            } else {
                Write-Host $interfaceName;
            }
        }
    }
    Write-Host "";
}

function Show-WgConnection {
    $currentConfig = Get-WgCurrentConfig
    $conf = $currentConfig.Config;    

    $sanitized = Hide-SensitiveData $conf
    Write-Host ''
    Write-Host $sanitized
    Write-Host ''
}

function Start-WgConnection {
    param (
        [string] $interfaceName
    )

    $interfaceExists = Test-WgInterfaceExists $interfaceName;
    if (-not $interfaceExists) {
        Write-Error "The interface $interfaceName does not exist." 
        exit 1
    }

    $activeInterfaceName = Get-WgActiveInterfaceName;
    if ($null -ne $activeInterfaceName -and $interfaceName -ne $activeInterfaceName) {
        Stop-WgConnection $activeInterfaceName
        Start-Sleep 1
    }

    Write-Host "Starting connection: $interfaceName..."
    wireguard /installtunnelservice "$wgConfDir/$interfaceName.conf.dpapi"
}

function Stop-WgConnection {
    param (
        [string] $interfaceName
    )

    $activeInterfaceName = Get-WgActiveInterfaceName;
    if ($interfaceName -ne $activeInterfaceName) {
        Write-Error "The interface $interfaceName is not currently running and thus cannot be stopped."
        exit 1
    }

    Write-Host "Stopping connection: $interfaceName..."
    wireguard /uninstalltunnelservice $interfaceName    
}

function Restart-WgConnection {
    $activeInterfaceName = Get-WgActiveInterfaceName;

    if ($null -eq $activeInterfaceName) {
        Write-Error "Cannot restart as no interface is currently active." 
        exit 1
    }

    Write-Host "Restarting interface: $activeInterfaceName..."
    Stop-WgConnection $activeInterfaceName
    Start-Sleep -Seconds 1
    Start-WgConnection $activeInterfaceName
}

function Rename-WgConnection {
    param (
        [string] $newInterfaceName
    )

    # Backup conf
    $currentConfig = Backup-WgConf
    $interfaceName = $currentConfig.InterfaceName;
    $conf = $currentConfig.Config;

    # Delete old interface
    Remove-WgConnection $interfaceName

    # Save wg conf
    $wgConfPath = "$wgConfDir/$newInterfaceName.conf";
    Save-File $wgConfPath $conf

    Write-Host "Wrote new config to: "
    Write-Host "- $wgConfPath"

    # Restart
    Start-Sleep -Seconds 1
    Start-WgConnection $newInterfaceName
}

function Backup-WgConnection {
    $currentConfig = Backup-WgConf
}

function Import-WgConnection {
    param (
        [string] $importConfPath,
        [bool] $force
    )

    if (-not (Test-Path $importConfPath)) { 
        $fullPath = Resolve-Path $importConfPath
        Write-Error "The path '$fullPath' could not be resolved."
        exit 1
    }

    $interfaceName = [System.IO.Path]::GetFileNameWithoutExtension($importConfPath)

    # Check if already exists
    $interfaceAlreadyExists = Test-WgInterfaceExists $interfaceName;
    $interfaceWasActive = (Get-WgActiveInterfaceName) -eq $interfaceName;
    
    if ($interfaceAlreadyExists) {
        if (-not $force) {
            Write-Error "The interface $interfaceName already exists. Use the '-force' option to overwrite it." 
            exit 1
        }
        
        # Backup conf
        if ($interfaceWasActive) { Backup-WgConf | Out-Null }

        # Delete old interface conf, but without closing the connection!
        # This is to not break a potential SSH connection running this script over the WG Tunnel and locking yourself out.
        # This way, the conf is swapped out, but you need to manually restart the WG tunnel to actually apply it.
        Remove-WgConnection $interfaceName $false
    }

    # Raw imports it with line breaks
    $importConf = Get-Content -Path $importConfPath -Raw

    # Backup new conf
    New-Item -ItemType Directory -Force -Path $backupDir | Out-Null
    $timestamp = Get-Timestamp
    $newConfPath = "$backupDir/$interfaceName-$timestamp.new.conf"
    Save-File $newConfPath $importConf

    # Save wg conf
    $wgConfPath = "$wgConfDir/$interfaceName.conf"
    Save-File $wgConfPath $importConf

    Write-Host "Wrote new config to: "
    Write-Host "- $newConfPath (as reference)"
    Write-Host "- $wgConfPath"

    # If is active conf
    if ($interfaceWasActive) {
        Write-Host ""
        Write-Warning "The configuration was successfully updated, but you need to manually restart the interface to apply it."
        Write-Host ""
    }
}
function New-WgConnection {
    param (
        [string] $interfaceName,
        [bool] $force
    )

    # Check if already exists
    $interfaceAlreadyExists = Test-WgInterfaceExists $interfaceName;
    $interfaceWasActive = (Get-WgActiveInterfaceName) -eq $interfaceName;

    if ($interfaceAlreadyExists) {
        if (-not $force) {
            Write-Error "The interface $interfaceName already exists. Use the '-force' option to overwrite it." 
            exit 1
        }
        
        # Backup conf
        if ($interfaceWasActive) { Backup-WgConf | Out-Null }

        # Delete old interface
        Remove-WgConnection $interfaceName $false
    }

    $privateKey=$(wg genkey)
    $publicKey=$(Write-Output "$privateKey" | wg pubkey)
    $emptyConf = "[Interface]`r`nPrivateKey = $privateKey"

    # Save new conf
    New-Item -ItemType Directory -Force -Path $newConfDir | Out-Null
    $newConfPath = "$newConfDir/$interfaceName.conf"
    Save-File $newConfPath $emptyConf

    Write-Host "Wrote new config to: "
    Write-Host "- $newConfPath"
    Write-Host ''
    Write-Host "The public key is: $publicKey"
    Write-Host ''
}

function Remove-WgConnection {
    param (
        [string] $interfaceName,
        [bool] $closeFirst = $true
    )

    # If active, shutdown interface before deleting it. This is actually optional,
    # you can delete the .dpapi file without the connection breaking.
    if ($closeFirst -and (Get-WgActiveInterfaceName) -eq $interfaceName) {
        Stop-WgConnection $interfaceName
        Start-Sleep 1
    }

    $wgConfPath = "$wgConfDir/$interfaceName.conf";
    if (Test-Path "$wgConfPath.dpapi") { 
        Remove-Item "$wgConfPath.dpapi" 
        Write-Host "Deleted: $wgConfPath.dpapi"
    }
}

Export-ModuleMember -Function Show-WgConnections
Export-ModuleMember -Function Show-WgConnection
Export-ModuleMember -Function Start-WgConnection
Export-ModuleMember -Function Stop-WgConnection
Export-ModuleMember -Function Restart-WgConnection
Export-ModuleMember -Function Rename-WgConnection
Export-ModuleMember -Function Backup-WgConnection
Export-ModuleMember -Function Import-WgConnection
Export-ModuleMember -Function New-WgConnection
Export-ModuleMember -Function Remove-WgConnection