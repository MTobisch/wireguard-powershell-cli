param (
    [string] $interfaceName,
    [bool] $closeFirst = $true
)

Import-Module "$PSScriptRoot/../Src/Operations.psm1" -Force

Remove-WgConnection -interfaceName $interfaceName -closeFirst $closeFirst