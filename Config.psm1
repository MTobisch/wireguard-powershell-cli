$backupDir = "$PSScriptRoot/Backups"
$newConfDir = "$PSScriptRoot/New"
$wgConfDir = (Split-Path -Parent (Get-Command wg).Source) + "/Data/Configurations";

Export-ModuleMember -Variable backupDir
Export-ModuleMember -Variable newConfDir
Export-ModuleMember -Variable wgConfDir