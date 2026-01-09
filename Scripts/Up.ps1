param (
    [string] $interfaceName
)

Import-Module "$PSScriptRoot/../Src/Operations.psm1" -Force

Start-WgConnection -interfaceName $interfaceName