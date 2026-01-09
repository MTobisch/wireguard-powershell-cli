param (
    [string] $newInterfaceName
)

Import-Module "$PSScriptRoot/../Src/Operations.psm1" -Force

Rename-WgConnection -newInterfaceName $newInterfaceName