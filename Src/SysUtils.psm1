# Starts a script file as a background task so that it will keep running even if the connection to the calling 
# bash process breaks (such as when restarting a wg connection via SSH over that same wg connection)
function Start-BackgroundTask {
    param (  
        [string] $scriptFileWithOptions
    )

    $startup = [ciminstance]::new((Get-CimClass Win32_ProcessStartup))
    $startup.ShowWindow = 0
    Invoke-CimMethod -ClassName Win32_Process -MethodName Create -Arguments @{
        CommandLine = "powershell.exe -ExecutionPolicy Bypass -WindowStyle Hidden -File $scriptFileWithOptions"
        ProcessStartupInformation = $startup
    } | Out-Null
}

Export-ModuleMember -Function Start-BackgroundTask