param (
    [string] $interfaceName,
    [bool] $force
)

Import-Module "$PSScriptRoot/../Src/Operations.psm1" -Force

New-WgConnection -interfaceName $interfaceName -force $force