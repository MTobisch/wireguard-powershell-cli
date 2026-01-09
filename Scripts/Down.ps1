param (
    [string] $interfaceName
)

Import-Module "$PSScriptRoot/../Src/Operations.psm1" -Force

Stop-WgConnection -interfaceName $interfaceName