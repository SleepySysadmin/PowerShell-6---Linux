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

Function Join-ADDomain
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$True)]
        [string]$UserName,
        [Parameter(Mandatory=$True)]
        [string]$Domain,
        [Parameter(Mandatory=$True)]
        [bool]$IsAzureVM
    )

    # Cat output, because why not. Doing it for DevOps...
    Write-Output "              ________________"
    Write-Output "             |                |_____    __"
    Write-Output "             |   PS Join AD!  |     |__|  |_________  __________"
    Write-Output "             |________________|_____|::|__|        / |_________/"
    Write-Output " /\**/\      |                \.____|::|__|______<"
    Write-Output "( o_o  )_    |                      \::/"
    Write-Output " (u--u   \_)  |"
    Write-Output "  (||___   )==\"
    Write-Output ",dP'b/=( /P'/b \"
    Write-Output "|8 || 8\=== || 8"
    Write-Output "'b,  ,P  'b,  ,P"
    Write-Output "'''''    ''''''"
    Write-Output " "
    Write-Output "_________________________________________________________________"
    Write-Output " "

    # Dramatic pause
    For ($i=5; $i -gt 1; $i–-)
    {  

        Write-Progress -Activity "Pausing for dramatic effect, in order to build suspense..." -SecondsRemaining $i
        Start-Sleep 1

    }

    # Checking if the host is indeed a linux machine, exiting if it's not true
    if (!$IsLinux)
    {
        
        Write-Error -Message 'This host is not Linux, ya dingus!'
        Exit

    }

    # Checking is this server is pointing to a domain controller for DNS. If not this will not work.
    If ($IsAzureVM -eq $True)
    {

        $DNSSettings = Read-Host "Did you set the DNS servers in the Azure Portal? Y or N:"
        If($DNSSettings -eq "Y")
        {

            Write-Output "Good, moving on..."

        }

        ElseIf ($DNSSettings -eq "N")
        {

            Write-Error "You need to point this server to a Domain Controller for DNS within the Azure portal. Otherwise you cannot join the domain"
            Write-Error "See https://docs.microsoft.com/en-us/azure/virtual-network/virtual-network-network-interface#change-dns-servers for assistance"
            Write-Output " "
            Write-Error "Exiting..."
            Exit

        }

    }

    Else
    {
        # Steps for adding content to resolv.conf in each distro section
        $null
        
    }

    # Gathering the version of the Operating System here. Depending on what OS we are working with dictates how we join the domain.
    $DistroVersion = Get-Content -Path "/etc/os-release" | ConvertFrom-StringData

    Write-Debug "Captured Distro Information"

    # Ubuntu 18.04
    If ($DistroVersion.name -Like "*Ubuntu*" -and $DistroVersion.Version_ID -Like "*18.04*")
    {

        Write-Output "OS that was detected:"
        Write-Output $DistroVersion.PRETTY_NAME 
        Start-Sleep -Seconds 2

        # Guide here: https://help.ubuntu.com/lts/serverguide/sssd-ad.html.en

        # Installing packages
        Write-Warning "Installing packages. As part of the installation of krb5-user, you will be asked to enter the domain you will be joining. Provide the domain name in all caps..."
        Start-Sleep -Seconds 5
        apt install -y krb5-user samba sssd chrony

        # Making a backup of config files, just incase something goes wrong. New directory created under current users home directory
        Write-Output "Backing up current config files to ~/Config_Backup..."

        mkdir ~/Config_Backup
        cp /etc/krb5.conf ~/Config_Backup 
        cp /etc/chrony/chrony.conf ~/Config_Backup
        cp /etc/samba/smb.conf ~/Config_Backup
        cp /etc/hosts ~/Config_Backup

        # Begin replacing config files here
        Write-Output "Deploying new config files required for joining the domain..."

        cp ~/AD_Join/Config_Files/Ubuntu_18.04/krb5.conf /etc/krb5.conf
        cp ~/AD_Join/Config_Files/Ubuntu_18.04/chrony.conf /etc/chrony/chrony.conf
        cp ~/AD_Join/Config_Files/Ubuntu_18.04/smb.conf /etc/samba/smb.conf
        cp ~/AD_Join/Config_Files/Ubuntu_18.04/sssd.conf /etc/sssd/sssd.conf


        # Set permissions on sssd.conf
        Write-Output "Setting permissions on sssd config files..."
        chown root:root /etc/sssd/sssd.conf
        chmod 600 /etc/sssd/sssd.conf

        # Warning w/ another dramatic pause
        Write-Warning "Making entry in /etc/hosts. Remember to set your IP to static in the Azure portal if this a Azure VM!"
        Start-Sleep -Seconds 3

        # Variables for entry to /etc/hosts
        $eth0IP = hostname -I | awk '{print $1}'
        $Hostname = hostname

        Add-Content -Path /etc/hosts -Value "$eth0IP $hostname $hostname.$Domain" -Force

        If ($IsAzureVM -eq $False)
        {

            $DNSServer = Read-host "Please supply the IP address of a Domain Controller to add to resolv.conf:"
            Add-Content -Path /etc/resolv.conf -Value $DNSServer -Force 

        }

        # Here we go
        Try
        {

            Write-Output "Starting services..."
            systemctl restart chrony.service
            systemctl restart smbd.service nmbd.service 
            systemctl start sssd.service

        }
        Catch
        {

            Write-Error $Error[0]
            Exit

        }

        # Testing Kerberos
        Write-Output "Services started succesfully! Testing authentication..."
        Start-Sleep -Seconds 1
        kinit $UserName
        klist

        # This is it!
        Write-Output "Joining the $Domain domain..."
        Start-Sleep -Seconds 3

        net ads join -k

    }

    # Ubuntu 16.04
    ElseIf ($DistroVersion.name -Like "*Ubuntu*" -and $DistroVersion.Version_ID -Like "*16.04*")
    {

        # Guide used here: https://www.tecmint.com/join-ubuntu-to-active-directory-domain-member-samba-winbind

        Write-Output "OS that was detected:"
        Write-Output $DistroVersion.PRETTY_NAME  
        Start-Sleep -Seconds 2

        # Installing and configuring packages
        Write-Output "Setting up ntp..."
        apt-get install -y ntpdate
        ntpdate -q $Domain
        ntpdate $Domain

        Write-Warning "Installing packages. As part of the installation of krb5-user, you will be asked to enter the domain you will be joining. Provide the domain name in all caps..."
        Start-Sleep -Seconds 5

        apt-get install -y samba krb5-config krb5-user winbind libpam-winbind libnss-winbind
        
        # Making a backup of config files, just incase something goes wrong. New directory created under current users home directory
        
        Write-Output "Backing up current config files to ~/Config_Backup/..."
        mkdir ~/Config_Backup
        cp /etc/samba/smb.conf ~/Config_Backup
        cp /etc/hosts ~/Config_Backup

        # Begin replacing config files here
        Write-Output "Deploying new config files required for joining the domain..."
        Start-Sleep -Seconds 3
        cp ~/AD_Join/Config_Files/Ubuntu_16.04/smb.conf /etc/samba/smb.conf

        # Warning w/ another dramatic pause
        Write-Warning "Making entry in /etc/hosts. Remember to set your IP to static in the Azure portal if this a Azure VM!"
        Start-Sleep -Seconds 3

        # Variables for entry to /etc/hosts
        $eth0IP = hostname -I | awk '{print $1}'
        $Hostname = hostname

        Add-Content -Path /etc/hosts -Value "$eth0IP $hostname $hostname.$Domain" -Force

        If ($IsAzureVM -eq $False)
        {

            $DNSServer = Read-host "Please supply the IP address of a Domain Controller to add to resolv.conf:"
            Add-Content -Path /etc/resolv.conf -Value $DNSServer -Force 

        }

        # Here we go
        Try
        {

            Write-Output "Starting services..."
            systemctl restart smbd nmbd winbind
            systemctl stop samba-ad-dc
            systemctl enable smbd nmbd winbind

        }
        Catch
        {

            Write-Error $Error[0]
            Start-Sleep -Seconds 2
            Exit

        }

        # Testing Kerberos
        Write-Output "Services started succesfully! Testing authentication..."
        Start-Sleep -Seconds 1
        kinit $UserName
        klist

        # This is it!
        Write-Output "Joining the $Domain domain..."
        Start-Sleep -Seconds 3

        net ads join -U $UserName
        Start-Sleep -Seconds 2

    }

    # CentOS 7.*
    ElseIf ($DistroVersion.name -Like "*CentOS Linux*" -and $DistroVersion.Version_ID -Like "*7*")
    {

        # Guide used here: https://www.linuxtechi.com/integrate-rhel7-centos7-windows-active-directory/

        Write-Output "OS that was detected:"
        Write-Output $DistroVersion.PRETTY_NAME 
        Start-Sleep -Seconds 2

        # Installing and configuring packages 
        yum install -y sssd realmd oddjob oddjob-mkhomedir adcli samba-common samba-common-tools krb5-workstation openldap-clients policycoreutils-python

        # Making a backup of config files, just incase something goes wrong. New directory created under current users home directory
        Write-Output "Backing up current config files to ~/Config_Backup..."
        mkdir ~/Config_Backup
        cp /etc/hosts ~/Config_Backup
        
        # Warning w/ another dramatic pause
        Write-Warning "Making entry in /etc/hosts. Remember to set your IP to static in the Azure portal if this a Azure VM!"
        Start-Sleep -Seconds 3

        # Variables for entry to /etc/hosts
        $eth0IP = hostname -I | awk '{print $1}'
        $Hostname = hostname

        Add-Content -Path /etc/hosts -Value "$eth0IP $hostname $hostname.$Domain" -Force

        If ($IsAzureVM -eq $False)
        {

            $DNSServer = Read-host "Please supply the IP address of a Domain Controller to add to resolv.conf:"
            Add-Content -Path /etc/resolv.conf -Value $DNSServer -Force 

        }

        # Here we go
        Try
        {

            Write-Output "Joining the $Domain domain..."
            Start-Sleep -Seconds 2
            realm join --user=$UserName $Domain

        }
        Catch
        {

            Write-Error $Error[0]
            Start-Sleep -Seconds 2
            Exit

        }

        # Outputing realm to display the domain information
        realm list
        Start-Sleep -Seconds 2

    }
    
    # RHEL 7.*
    ElseIf ($DistroVersion.name -Like "*Red Hat Enterprise Linux Server*" -and $DistroVersion.Version_ID -Like "*7*")
    {

        # Guide used here: https://www.linuxtechi.com/integrate-rhel7-centos7-windows-active-directory/

        Write-Output "OS that was detected:"
        Write-Output $DistroVersion.PRETTY_NAME 
        Start-Sleep -Seconds 2

        # Installing and configuring packages 
        yum install -y sssd realmd oddjob oddjob-mkhomedir adcli samba-common samba-common-tools krb5-workstation openldap-clients policycoreutils-python

        # Making a backup of config files, just incase something goes wrong. New directory created under current users home directory
        Write-Output "Backing up current config files to ~/Config_Backup..."
        mkdir ~/Config_Backup
        cp /etc/hosts ~/Config_Backup
        
        # Warning w/ another dramatic pause
        Write-Warning "Making entry in /etc/hosts. Remember to set your IP to static in the Azure portal if this a Azure VM!"
        Start-Sleep -Seconds 3

        # Variables for entry to /etc/hosts
        $eth0IP = hostname -I | awk '{print $1}'
        $Hostname = hostname

        Add-Content -Path /etc/hosts -Value "$eth0IP $hostname $hostname.$Domain" -Force

        If ($IsAzureVM -eq $False)
        {

            $DNSServer = Read-host "Please supply the IP address of a Domain Controller to add to resolv.conf:"
            Add-Content -Path /etc/resolv.conf -Value $DNSServer -Force 

        }

        # Here we go
        Try
        {

            Write-Output "Joining the $Domain domain..."
            Start-Sleep -Seconds 2
            realm join --user=$UserName $Domain

        }
        Catch
        {

            Write-Error $Error[0]
            Start-Sleep -Seconds 2
            Exit

        }

        # Outputing realm to display the domain information
        realm list
        Start-Sleep -Seconds 2

    }

    Else
    {
    
        Write-Warning "Sorry, dont have anything coded for this version of OS, going to have to do it manually :("
        Write-Warning "OS Version:"
        Write-Warning " "
        Write-Warning $DistroVersion.PRETTY_NAME 
        Write-Warning " "

    }

}

# https://www.youtube.com/watch?v=-W6as8oVcuM
Join-ADDomain
