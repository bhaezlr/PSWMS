$latestSession = $null
$latestAuth = $null

###
### General functions
###
function CheckSession
{
    if (($script:latestSession -eq $null) -or (((get-date) - $script:latestSession["Timestamp"]).TotalMinutes -gt 10)) {
        New-WmsApiSession 
    }
}

function Close-ApiSession 
{
    ###
    ### https://developer.dell.com/apis/3788/versions/3.5/docs/Getting%20Started/3authentication.md
    ###
    $uri = "https://$($script:latestSession[""Host""]):443/wms-api/wms/v1/SessionService/Sessions/$($script:latestSession[""SessionId""])"
    $result = Invoke-WebRequest -Uri $uri -Method Delete -Headers @{"Accept" = "*/*"; "X-Auth-Token" = $script:latestSession["X-Auth-Token"]}
}

function New-ApiSession
{
    <#
    .SYNOPSIS
    Create a new authenticated session which can be used to call the WMS REST API.
    
    .DESCRIPTION
    It must be called all other functions. It returns the actual session object, but usually
    this object is not needed as the module caches and reuses the latest successful session.

    The validity of the credentials is checked and an error is thrown if not.

    .INPUTS
    This function does not take pipe input.

    .OUTPUTS
    The session object.

    .SOURCE
    https://developer.dell.com/apis/3788/versions/3.5/docs/Getting%20Started/3authentication.md

    #>
    param(
        [string]$Server, 
        
        # The credentials used to authenticate. Use Get-Credential to create this object.
        [PSCredential]$Auth
        
    )

    if (($Auth -eq $null) -and ($script:latestAuth -eq $null)) {
        Write-Host "Inital call to New-WmsApiSession not made !!! Must be called from main-script." 
        exit
    }
    if ($Auth -eq $null) {$Auth = $script:latestAuth}
    if ($Server -eq "") {$Server = $script:latestSession["Host"]}

    $ApiUri = "https://$($Server):443/wms-api/wms/v1/SessionService/Sessions"
    $body= ConvertTo-Json(@{UserName = $Auth.UserName; Password = $Auth.GetNetworkCredential().Password})
    $result = Invoke-WebRequest -Uri $ApiUri -Method Post -ContentType "application/json" -Body $body -Headers @{Accept = "*/*"} -ErrorAction SilentlyContinue
    if (($result -eq $null) -or (($result.StatusCode -ne 201) -and ($result.StatusCode -ne 204))) {
        Write-Error -Message "Session could not be opened"
        exit
    }
    $script:latestSession = @{Host = $Server; "X-Auth-Token" = $result.Headers["X-Auth-Token"]; SessionId = (ConvertFrom-JSON ($result.Content)).Id; Timestamp = Get-Date}
    $script:latestSession
    $script:latestAuth = $auth
}

###
### Functions per device
###
function Get-DetailsDevice
{
    ###
    ### https://developer.dell.com/apis/3788/versions/4.3.0/docs/Tasks/3get_device_details.md
    ###
    param (
        [int] $deviceId
    )

    CheckSession
    $uri = "https://$($script:latestSession[""Host""]):443/wms-api/wms/v1/Systems/$deviceId"
    $result = Invoke-WebRequest -Uri $uri -Method Get -Headers @{"Accept" = "*/*"; "X-Auth-Token" = $script:latestSession["X-Auth-Token"]}
    if (($result -eq $null) -or ($result.StatusCode -ne 200)) {
        Write-Host "DeviceId not found !!"
    }

    return convertFrom-JSON ($result.content)
}

function Get-InstalledAppsDevice
{
    ###
    ### https://developer.dell.com/apis/3788/versions/4.3.0/docs/Tasks/9.8installedapplication.md
    ###
    param (
        [int] $deviceId
    )
    CheckSession

    $uri = "https://$($script:latestSession[""Host""]):443/wms-api/wms/v1/$deviceId/apps"
    $result = Invoke-WebRequest -Uri $uri -Method Get -Headers @{"Accept" = "*/*"; "X-Auth-Token" = $script:latestSession["X-Auth-Token"]}
    if (($result -eq $null) -or ($result.StatusCode -ne 200)) {
        Write-Error -Message "DeviceId not found !!"
    }

    convertFrom-Json ($result.Content)
}

function Get-LogfileDevice
{
    ###
    ### https://developer.dell.com/apis/3788/versions/4.3.0/docs/Tasks/8.7devicelogs.md
    ###
    param (
        [int] $deviceId
    )

    CheckSession
    $uri = "https://$($script:latestSession[""Host""]):443/wms-api/wms/v1/Systems/$deviceId/Actions/Oem/DellWyse.DeviceLogs"
    $result = Invoke-WebRequest -Uri $uri -Method POST -Headers @{"Accept" = "*/*"; "X-Auth-Token" = $script:latestSession["X-Auth-Token"]}
    if (($result -eq $null) -or ($result.StatusCode -ne 200)) {
        Write-Error -Message "DeviceId not found !!"
    }
}

function RestartDevice
{
    ###
    ### https://developer.dell.com/apis/3788/versions/4.3.0/docs/Tasks/8.4restartdevice.md
    ###
    param (
        [int] $deviceId
    )

    CheckSession
    $uri = "https://$($script:latestSession[""Host""]):443/wms-api/wms/v1/Systems/$deviceId/Actions/Oem/DellWyse.Restart"
    $result = Invoke-WebRequest -Uri $uri -Method POST -Headers @{"Accept" = "*/*"; "X-Auth-Token" = $script:latestSession["X-Auth-Token"]}
    if (($result -eq $null) -or ($result.StatusCode -ne 200)) {
        Write-Error -Message "DeviceId not found !!"
    }
}

function Send-MessageDevice
{
    ###
    ### https://developer.dell.com/apis/3788/versions/4.3.0/docs/Tasks/8.5sendmessagedevice.md
    ###
    param (
        [int] $deviceID,
        [string]$Message

    )

    $parameters = @{'@odata.id'   =  "/wms-api/wms/v1/Systems/1/Actions/Oem/SendMessageActionInfo"                                      
                    '@odata.type' = "#ActionInfo.v1_0_6.ActionInfo"
                    'Id'          = "SendMessageActionInfo"
                    'Name'        = "Dell Wyse Send Message Action Info"
                    'Parameters'  = @(@{'Name'            = "Message"
                                      'Required'        = $True
                                      'DataType'        = "String"
                                      'AllowableValues' = @($Message)
                                     })
                   }
    CheckSession
    $uri = "https://$($script:latestSession[""Host""]):443/wms-api/wms/v1/Systems/$deviceID/Actions/Oem/DellWyse.SendMessage"
    $body = ConvertTo-Json ($parameters) -Depth 5
    $result = Invoke-WebRequest -Uri $Uri -Method POST -ContentType "application/json" -Body $body -Headers @{Accept = "*/*"; "X-Auth-Token" = $script:latestSession["X-Auth-Token"]}
    if (($result -eq $null) -or ($result.StatusCode -ne 200)) {
        Write-Error -Message "Session could not be opened"
        exit
    }
}

function Send-QueryDevice
{
    ###
    ### https://developer.dell.com/apis/3788/versions/4.3.0/docs/Tasks/8.6device_query.md
    ###
    param (
        [int] $deviceId
    )

    CheckSession
    $uri = "https://$($script:latestSession[""Host""]):443/wms-api/wms/v1/Systems/$deviceId/Actions/Oem/DellWyse.DeviceQuery"
    $result = Invoke-WebRequest -Uri $uri -Method POST -Headers @{"Accept" = "*/*"; "X-Auth-Token" = $script:latestSession["X-Auth-Token"]}
    if (($result -eq $null) -or ($result.StatusCode -ne 200)) {
        Write-Error -Message "DeviceId not found !!"
    }
}

function ShutdownDevice
{
    ###
    ### https://developer.dell.com/apis/3788/versions/4.3.0/docs/Tasks/8.3shutdown.md
    ###
    param (
        [int] $deviceId
    )

    CheckSession
    $uri = "https://$($script:latestSession[""Host""]):443/wms-api/wms/v1/Systems/$deviceId/Actions/Oem/DellWyse.Shutdown"
    $result = Invoke-WebRequest -Uri $uri -Method POST -Headers @{"Accept" = "*/*"; "X-Auth-Token" = $script:latestSession["X-Auth-Token"]}
    if (($result -eq $null) -or ($result.StatusCode -ne 200)) {
        Write-Error -Message "DeviceId not found !!"
    }
}

function UnregisterDevice 
{
    ###
    ### https://developer.dell.com/apis/3788/versions/4.3.0/docs/Tasks/8.1unregister_device.md
    ###
    param (
        [int] $deviceId,
        [bool]$forced = $false
    )

    Write-Warning -Message "UnregisterDevice : This function does NOT work as documented in the API-documentation !!"
    CheckSession

    $uri = "https://$($script:latestSession[""Host""]):443/wms-api/wms/v1/Systems/$deviceId/Actions/Oem/DellWyse.Unregister"
    $body = convertTo-Json (@{force = $forced})
    $result = Invoke-WebRequest -Uri $uri -Method POST -Headers @{"Accept" = "*/*"; "X-Auth-Token" = $script:latestSession["X-Auth-Token"]}    ### -Body $body
    if (($result -eq $null) -or ($result.StatusCode -ne 200)) {
        Write-Error -Message "DeviceId not found !!"
    }
}

###
### Bulk functions
###
function Get-DeviceInventoryDetails
{
    ###
    ### https://developer.dell.com/apis/3788/versions/4.3.0/docs/Tasks/2device_inventory.md
    ###
    param (
        [string]$GroupFilter = "*",
        [string]$Serial = "",
        [string]$Filter = ""
    )

    $devices = @()
    CheckSession

    $uri = "https://$($script:latestSession[""Host""]):443/wms-api/wms/v1/Systems"
    if ($Serial -ne "") {
        $Filter = "Serial eq '$Serial'"
    }
    if ($Filter -ne "") {
        $Filter = "?`$filter=$Filter"
    }
    $result = Invoke-WebRequest -Uri "$uri$Filter" -Method Get -Headers @{"Accept" = "*/*"; "X-Auth-Token" = $script:latestSession["X-Auth-Token"]} # -ErrorAction SilentlyContinue
    if (($result -eq $null) -or ($result.StatusCode -ne 200)) {
        Write-Error -Message "No result returned !! Expired session ??"
        return $null
    }

    $content = ConvertFrom-JSON ($result.content)
    $devices += $content.Members
    $Filter = $Filter.Replace("?", "&")  #### Filter is not the first parameter. First parameter = page
    while ($content."Members@odata.nextlink" -ne $null) {
	    $uri = "https://$($script:latestSession[""Host""]):443/wms-api$($content."Members@odata.nextlink")$Filter"

	    $result = Invoke-WebRequest -Uri $uri -Method Get -Headers @{"Accept" = "*/*"; "X-Auth-Token" = $script:latestSession["X-Auth-Token"]}
	    if (($result -eq $null) -or ($result.StatusCode -ne 200)) {
            Write-Error -Message "No result returned !! Expired session ??"
            return $null
        }
        $content = ConvertFrom-JSON ($result.content)
        $devices += $content.Members
    }

    return $devices | select @{Name='ID';  Expression={($_."@odata.id").split("/")[4]}}, @{Name='Oem'; Expression={$_.oem}} | where-object {$_.oem.Group -like "$GroupFilter"}
}

function Get-GroupInventoryDetails
{
    ###
    ### https://developer.dell.com/apis/3788/versions/4.3.0/docs/Tasks/9.6get_group_inventory.md
    ###
    param (
        [string]$GroupFilter = "*"
    )

    $groups = @()
    CheckSession
    $uri = "https://$($script:latestSession[""Host""]):443/wms-api/wms/v1/DeviceGroups"
    $result = Invoke-WebRequest -Uri $uri -Method Get -Headers @{"Accept" = "*/*"; "X-Auth-Token" = $script:latestSession["X-Auth-Token"]}
    if (($result -eq $null) -or ($result.StatusCode -ne 200)) {
        Write-Host "Next page not found !! Expired session ??"
    }
    $content = ConvertFrom-JSON ($result.content)
    $groups += $content.Members
    while ($content."Members@odata.nextlink" -ne $null) {
	    $uri = "https://$($script:latestSession[""Host""]):443/wms-api$($content."Members@odata.nextlink")"

	    $result = Invoke-WebRequest -Uri $uri -Method Get -Headers @{"Accept" = "*/*"; "X-Auth-Token" = $script:latestSession["X-Auth-Token"]}
	    if (($result -eq $null) -or ($result.StatusCode -ne 200)) {
            Write-Error -Message "Next page not found !! Expired session ??"
        }
        $content = ConvertFrom-JSON ($result.content)
        $groups += $content.Members
    }

    return ($groups | select @{Name='GroupName';Expression={$_.oem.Name}}, @{Name='GroupData';Expression={$_.oem}} | Where-Object {$_.GroupName -like "$GroupFilter"})
}

function Send-MessageBulk
{
    ###
    ### https://developer.dell.com/apis/3788/versions/4.3.0/docs/Tasks/9.4send_message_bulk.md
    ###
    param (
        [array]$Serials,
        [array]$MACAddresses,
        [string]$Message
    )

    $parameters = @{'@odata.id'   =  "/wms-api/wms/v1/Actions/Oem/SendMessageActionInfo"
                    '@odata.type' = "#ActionInfo.v1_0_6.ActionInfo"
                    'Id'          = "SendMessageActionInfo"
                    'Name'        = "Dell Wyse Send Message Action Info"
                    'Parameters'  = @()
                   }
    if ($Serials -ne $null) {
        $parameter = @{'Name'            = "SerialNumber"
                       'Required'        = $True
                       'DataType'        = "String"
                       'AllowableValues' = @()
                      }
        ForEach ($serial in $serials) {
            $parameter.AllowableValues += $Serial
        }
        $parameters.Parameters += $parameter
    }

    if ($MACAddresses -ne $null) {
        $parameter = @{'Name'            = "MACAddress"
                       'Required'        = $True
                       'DataType'        = "String"
                       'AllowableValues' = @()
                      }
        ForEach ($mac in $MACAddresses) {
            $parameter.AllowableValues += $mac
        }
        $parameters.Parameters += $parameter
    }

    ### The Message
    $parameter = @{'Name'            = "Message"
                   'Required'        = $True
                   'DataType'        = "String"
                   'AllowableValues' = @($Message)
                  }
    $parameters.Parameters += $parameter

    CheckSession
    $uri = "https://$($script:latestSession[""Host""]):443/wms-api/wms/v1/Actions/Oem/DellWyse.SendMessage"
    $body = ConvertTo-Json ($parameters) -Depth 5
    $result = Invoke-WebRequest -Uri $Uri -Method Post -ContentType "application/json" -Body $body -Headers @{Accept = "*/*"; "X-Auth-Token" = $script:latestSession["X-Auth-Token"]}
    if (($result -eq $null) -or ($result.StatusCode -ne 200)) {
        Write-Error -Message "Session could not be opened"
        exit
    }
}


###
###  TODO : Functions to build
###
function Get-LicenseInfo
{
 ###
 ### https://developer.dell.com/apis/3788/versions/4.3.0/docs/Tasks/7license_monitoring.md
 ###
}

function Set-GroupDevice
{
 ###
 ### https://developer.dell.com/apis/3788/versions/4.3.0/docs/Tasks/8.0change_device_group.md
 ###
}

function FactoryResetDevice
{
 ###
 ### https://developer.dell.com/apis/3788/versions/4.3.0/docs/Tasks/8.2factory_reset.md
 ###
}

function Set-GroupBulk
{
 ###
 ### https://developer.dell.com/apis/3788/versions/4.3.0/docs/Tasks/9.0change_group_bulk.md
 ###
}

function UnregisterBulk
{
 ###
 ### https://developer.dell.com/apis/3788/versions/4.3.0/docs/Tasks/9.1unregister_bulk_devices.md
 ###
}

function RestartBulk
{
 ###
 ### https://developer.dell.com/apis/3788/versions/4.3.0/docs/Tasks/9.2restart_bulk_devices.md
 ###
}

function ShutdownBulk
{
 ###
 ### https://developer.dell.com/apis/3788/versions/4.3.0/docs/Tasks/9.3shutdown_bulk_devices.md
 ###
}

function FactoryResetBulk
{
 ###
 ### https://developer.dell.com/apis/3788/versions/4.3.0/docs/Tasks/9.5factoryreset_bulk.md
 ###
}

