# What is PSWMS

A powershell module to interact with the Dell Wyse Managment Suite.

# Goals

...

# Installation

The module is published on the PowerShell gallery, so download and installation is simply (powershell 5+):

```
PS> Install-Module PSWMS -scope CurrentUser
```

If using an older version of PowerShell, you must download the release from the releases page, unzip it 
and put the PSWMS folder inside MyDocuments/WindowsPowerShell/Modules or any other folder in the module 
search path.

# Usage

...

```
# Import the module (if old powershell version)
PS> Import-Module PSWMS

# You must first create a session against a WMS console - only needed once per work session.
PS> New-WmsApiSession -Server "<FQDN>" -Auth (Get-Credential MyAdminLogin)

# Then call any cmdlet
PS> Get-WmsDeviceDetails -deviceId <id>

...

# List of cmdlets (the Wms prefix can be changed on import if needed):
PS> Get-Command -Module PSWMS
CommandType     Name                                               Version    Source                                                                                                                                                                             
-----------     ----                                               -------    ------                                                                                                                                                                             
Function        Close-WmsApiSession                                1.0.0      PSWMS                                                                                                                                                                              
Function        Get-WmsDeviceDetails                               1.0.0      PSWMS                                                                                                                                                                              
Function        Get-WmsDeviceInventoryDetails                      1.0.0      PSWMS                                                                                                                                                                              
Function        Get-WmsGroupInventoryDetails                       1.0.0      PSWMS                                                                                                                                                                              
Function        Get-WmsInstalledApps                               1.0.0      PSWMS                                                                                                                                                                              
Function        Get-WmsLogfileDevice                               1.0.0      PSWMS                                                                                                                                                                              
Function        New-WmsApiSession                                  1.0.0      PSWMS                                                                                                                                                                              
Function        Send-WmsBulkMessage                                1.0.0      PSWMS                                                                                                                                                                              
Function        Send-WmsMessage                                    1.0.0      PSWMS                                                                                                                                                                              
Function        Send-WmsQueryDevice                                1.0.0      PSWMS                                                                                                                                                                              
Function        WmsRestartDevice                                   1.0.0      PSWMS                                                                                                                                                                              
Function        WmsShutdownDevice                                  1.0.0      PSWMS                                                                                                                                                                              
Function        WmsUnregisterDevice                                1.0.0      PSWMS                                                                                                                                                                              
```
