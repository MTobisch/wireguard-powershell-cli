param (
    [switch] $list,
    [string] $up,
    [string] $down,
    [switch] $restart,
    [string] $new,
    [string] $address,
    [String] $import,
    [switch] $force,
    [string] $rename,
    [switch] $print,
    [switch] $backup,    
    [string] $delete
)

Import-Module "$PSScriptRoot/src/sysUtils.psm1" -Force

$ErrorActionPreference = "Stop"

$operationCount = 0;
if ($list) { $operationCount++ }
if ($up) { $operationCount++ }
if ($down) { $operationCount++ }
if ($restart) { $operationCount++ }
if ($new) { $operationCount++ }
if ($import) { $operationCount++ }
if ($rename) { $operationCount++ }
if ($print) { $operationCount++ }
if ($backup) { $operationCount++ }
if ($delete) { $operationCount++ }

if ($operationCount -gt 1) {
    Write-Error "You can only choose one of the following options at a time: 'list', 'up', 'down', 'restart', 'new', 'import', 'rename', 'print', 'backup', 'delete'."
    exit 1
}

if ($force -and -not ($new -or $import)) {
    Write-Error "The 'force' option can only be used with the 'new' or 'import' options."
    exit 1
}

# Operation: None
# -----------------------------------------------
if ($operationCount -eq 0) {
    Write-Host @"
This tools allows easy management of Wireguard connections in Windows via an elevated CLI.

Usage:
- List all available configs        WgCli.ps1 -list
- Activate config:                  WgCli.ps1 -up INTERFACE_NAME
- Deactivate config:                WgCli.ps1 -down INTERFACE_NAME
- Restart active config:            WgCli.ps1 -restart
- Print active config:              WgCli.ps1 -print
- Rename active config:             WgCli.ps1 -rename NEW_INTERFACE_NAME
- Backup active config:             WgCli.ps1 -backup
- Import config:                    WgCli.ps1 -import CONFIG_FILE
- Create empty config:              WgCli.ps1 -new INTERFACE_NAME
- Delete config:                    WgCli.ps1 -delete INTERFACE_NAME

"@

exit 0;
}

# Operation: List
# -----------------------------------------------

if ($list) {
    $scriptPath = "$PSScriptRoot/Scripts/List.ps1"
    & $scriptPath
}

# Operation: Up
# -----------------------------------------------

elseif ($up) {
    $scriptPath = "$PSScriptRoot/Scripts/Up.ps1"
    & $scriptPath -interfaceName $up
}

# Operation: Down
# -----------------------------------------------

elseif ($down) {
    $scriptPath = "$PSScriptRoot/Scripts/Down.ps1"
    & $scriptPath -interfaceName $down
}

# Operation: Restart
# -----------------------------------------------

elseif ($restart) {
    Write-Host "Restarting active interface..."
    Write-Host "Note: This task runs as a background-process and might take a moment to complete."
    Start-BackgroundTask "$PSScriptRoot/Scripts/Restart.ps1"
}

# Operation: New
# -----------------------------------------------

elseif ($new) {
    $scriptPath = "$PSScriptRoot/Scripts/New.ps1"
    & $scriptPath -interfaceName $new -force $force
}

# Operation: Import
# -----------------------------------------------

elseif ($import) {
    $scriptPath = "$PSScriptRoot/Scripts/Import.ps1"
    & $scriptPath -importConfPath $import -force $force
}

# Operation: Sync
# -----------------------------------------------
elseif ($sync) {
    $scriptPath = "$PSScriptRoot/Scripts/Sync.ps1"
    & $scriptPath -swapAddress $address
}

# Operation: Rename
# -----------------------------------------------

elseif ($rename) {
    Write-Host "Renaming active interface to: $rename."
    Write-Host "Note: This task runs as a background-process and might take a moment to complete."
    Start-BackgroundTask "$PSScriptRoot/Scripts/Rename.ps1 $rename"
}

# Operation: Print
# -----------------------------------------------

elseif ($print) {
    $scriptPath = "$PSScriptRoot/Scripts/Print.ps1"
    & $scriptPath
}

# Operation: Backup
# -----------------------------------------------

elseif ($backup) {
    $scriptPath = "$PSScriptRoot/Scripts/Backup.ps1"
    & $scriptPath
}

# Operation: Delete
# -----------------------------------------------

elseif ($delete) {
    $scriptPath = "$PSScriptRoot/Scripts/Delete.ps1"
    & $scriptPath -InterfaceName $delete -closeFirst $true
}

exit 0;
