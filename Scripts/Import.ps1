param (
    [string] $importConfPath,
    [bool] $force
)

Import-Module "$PSScriptRoot/../Src/Operations.psm1" -Force

Import-WgConnection -importConfPath $import -force $force