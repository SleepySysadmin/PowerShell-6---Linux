# Join Active Directory on Linux with PowerShell 6!

## Requirements
In order for this to work, you'll need to have PowerShell Core installed on the machine. See the Microsoft guide below for your particular distro:

https://docs.microsoft.com/en-us/powershell/scripting/install/installing-powershell-core-on-linux?view=powershell-6

If you are joining a Ubuntu machine to your Active Directory domain, you'll need to update the config files, bundled with this script, with information relitative to your AD domain. Examples below:

![image](https://github.com/SleepySysadmin/PowerShell-6---Linux/blob/master/AD_Join/Images/smbconf-example.png)

![image](https://github.com/SleepySysadmin/PowerShell-6---Linux/blob/master/AD_Join/Images/sssdconf-example.png)

## Comment Based Help
```PowerShell
<#
    .SYNOPSIS
        PowerShell script for joining a Linux machine to the domain. Prior to running this on Ubuntu, you need to update the config files
        with information relitative to your Active Directory domain.

    .DESCRIPTION
        This script installs the nessecery packages required to join an Active Directory domain. Checks what version of OS is installed and 
        takes the nessecery steps needed to join the domain. When this script is ran, the PWD needs to be /root/AD_Join, otherwise the paths
        will not work for fetching the config files.

        In order for Ubuntu distros to join the domain, you will need to update the config files in AD_Join/Config_Files prior to this script running. 

    .PARAMETER Username
        Provide the username you will be using to join the domain.

    .PARAMETER Username
        Name of the domain you will be joining. 

    .PARAMETER IsAzureVM
        There are a few requirements that need to be done in the Azure portal prior to this running, namely setting the DNS servers for the NIC.
        This is also a boolean, so either True or False as the value.

    .NOTES
        .NET core and PowerShell version 6.x must be installed prior to running. Must also be ran as the root user. It is also assumed this is on a fresh OS install.
        See https://docs.microsoft.com/en-us/powershell/scripting/install/installing-powershell-core-on-linux?view=powershell-6 for assistance.

#>
```
