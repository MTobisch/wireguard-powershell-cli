# Wireguard Powershell CLI
This is a simple Powershell CLI for managing Wireguard connections after installing the [Windows Wireguard Client](https://www.wireguard.com/install/). 

It offers improved ease-of-use when compared to the standard `wg` command, such as the ability the handle `wg-quick`-style configuration files (the same as the Wireguard UI) and more.

It features the following operations:

| Operation | Syntax |
| -------- | ------- |
| List all tunnels  | `WgCli.ps1 -list`  |
| Activate tunnel | `WgCli.ps1 -up TUNNEL_NAME` |
| Deactivate tunnel | `WgCli.ps1 -down TUNNEL_NAME` |
| Restart active tunnel | `WgCli.ps1 -restart` |
| Print active tunnel | `WgCli.ps1 -print` |
| Rename active tunnel | `WgCli.ps1 -rename NEW_TUNNEL_NAME` |
| Backup active tunnel | `WgCli.ps1 -backup` |
| Import tunnel | `WgCli.ps1 -import CONFIG_FILE` |
| Create empty tunnel | `WgCli.ps1 -new TUNNEL_NAME` |
| Delete tunnel | `WgCli.ps1 -delete TUNNEL_NAME` |

## Installation
Simply download this repository into a folder of your choice, for example with:

`git clone https://github.com/MTobisch/wireguard-powershell-cli.git`

To then use this tool, the following must be true:
1. The [Windows Wireguard Client](https://www.wireguard.com/install/) must be installed.
2. It must be called from an elevated Powershell session (admin rights)
3. Since it is a plain script, the current Powershell execution policy must allow it to run. This can be accomplished either by calling it like `powershell -ExecutionPolicy Bypass .\WgCli.ps1` or by disabling security checks in general via `Set-ExecutionPolicy Bypass -Scope CurrentUser` after which it works with just `./WgCli.ps1`.

## Configuration
The root dir has a `Config.psm1` file, which contains some variables like folder paths that can be adjusted, if needed. This is entirely optional and shouldn't be necessary, though.

## Creating & updating connections
To create a new connection from a `wg-quick`-style configuration file, you can simply use the `-import CONFIG_FILE` operation.

To then update that connection later on, its easiest to just use the `-import` operation again, this time with the `-force` option to overwrite a configuration with the same name.

**Note:** The new configuration is **not** immediately applied if it is currently running as an active tunnel. To apply the changes, you need to manually restart the tunnel (for example via the `-restart` operation).

## Running commands over SSH
For remote maintenance purposes, it is often desirable to update Wireguard configurations from afar. This can be a problem as its easy to saw off the branch you're sitting on when the SSH connection itself connects via the very Wireguard tunnel that you're tying to edit.

For this purpose, some operations that close the Wireguard tunnel (temporarily) like `-restart` or `-rename` have "disconnect-protection" built-in and are run as background tasks. This means that while the SSH connection will inevitably disconnect, the command itself will not cancel, but proceed to finish normally and start the tunnel again. You can then simply reestablish the SSH connections shortly afterwards.

## Limitations
This project is not meant to be a full implementation of all `wg-quick` features, but is instead intended to help alleviate some of the most common everyday pains and shortcomings when trying to manage Wireguard connections in Windows via the CLI. 

As such, the tool has not been tested with more advanced configurations.

