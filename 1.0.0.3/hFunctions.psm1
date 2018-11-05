<#
.SYNOPSIS
Lists Blade Servers within HP Blade Chassis
.DESCRIPTION
Returns an object of Chassis, Bay and Blade for all HPe enclosures specified.  See Examples.
Requires providing Onboard Admin credentials.  Use $MyCreds = Get-Credential to generate credentials.
Requires HPe cmdlets Connect-HPEOA & Get-HPEOAServerList from module HPEOACmdlets; see https://github.com/hewlettpackard/
If error "...PSCredential is not supported"  Changing "[pscredential]$Credential" to simply $credential" in the Parameter
block is a workaround.'
.PARAMETER Name
Specify chassis by OnBoard Admin Name.  Example: MyChassis07-OA1.MyCompany.Org
Normally the active OnBoard Admin will be OA1.  On a rare occassion it might be OA2.
.PARAMETER Credential
Mandatory.  For Onboard Admin access.  Use $MyCreds = Get-Credential to generate credentials.
.OUTPUTS
PSCUSTOMOBJECT SupSkiFun.BladeInfo
.LINK
https://github.com/hewlettpackard/
.EXAMPLE
Query one blade chassis by Name:
$MyCreds = Get-Credential
Show-Blade -Name MyChassis07-OA1.MyCompany.Org -Credential $MyCreds
.EXAMPLE
Return object of 3 blade chassis into a variable, querying by Name:
$MyCreds = Get-Credential
$MyVar = Show-Blade -Name MyChassis01-OA1, MyChassis02-OA1, MyChassis03-OA1 -Credential $MyCreds
#>
function Show-Blade
{
    #[PSCredential]$Credential	Connect-HPOA errors when this is set despite using a pscredential so generic type used.
	[CmdletBinding()]
    param
    (
		[Parameter(ValueFromPipelineByPropertyName = $true)]
		[Alias("BC","OA")]
        $Name,

		[Parameter(Mandatory = $true,
			HelpMessage = "Pipe in Credentials",
			ValueFromPipeline = $true)]
		[pscredential]$Credential
	)

    Begin
    {
		$module = "HPEOACmdlets"
		$errmsg = " is required.  See https://github.com/hewlettpackard/"
		if(-not (Get-Command -Module $module -ErrorAction SilentlyContinue))
		{
			Write-Output "Module $module $errmsg"
			break
		}
    }

    Process
    {
		$conn = Connect-HPEOA -Credential $Credential -OA $name
		$bls = Get-HPEOAServerList -Connection $conn

		foreach ($b in $bls)
		{
			if ($b.StatusType -notmatch "OK")
			{
				$loopobj = [pscustomobject]@{
					Chassis = $b.Hostname
					Bay = $b.StatusType
					Blade = $b.StatusMessage
				}
			$loopobj.PSObject.TypeNames.Insert(0,'SupSkiFun.BladeInfo')
			$loopobj
			}
			else
			{
				foreach ($c in $b.serverlist)
				{
					$loopobj = [pscustomobject]@{
						Chassis = $b.Hostname
						Bay = $c.Bay
						Blade = $c.iLOName
					}
				$loopobj.PSObject.TypeNames.Insert(0,'SupSkiFun.BladeInfo')
				$loopobj
				}
			}
		}
    }
}

<#
.SYNOPSIS
Retrieves HPe ILO SMTP Secure Email Connection Setting on ILO 5.
.DESCRIPTION
Retrieves HPe ILO SMTP Secure Email Connection Setting on ILO 5 only.
Not Applicable to ILO 4 and lower; will return Not Attempted.
Returns an object of Hostname and AlertMailSMTPSecureEnabled.
Requires Credential Object generated from Get-Credential.
Requires Module HPERedfishCmdlets: https://www.powershellgallery.com/packages/HPERedfishCmdlets/1.0.0.2
Optionally sends a test email when complete.
.PARAMETER ILO
FQDN of ILO(s).
.PARAMETER Credential
PSCredential generated from Get-Credential.
.PARAMETER DisableCertificateAuthentication
If this switch parameter is present then server certificate authentication is disabled for the execution of this cmdlet. If not present it will execute
according to the global certificate authentication setting. The default is to authenticate server certificates. See Enable-HPERedfishCertificateAuthentication
and Disable-HPERedfishCertificateAuthentication to set the per PowerShell session default.
.PARAMETER TestEmail
Use if a post configuration test email is desired.
.OUTPUTS
PSCUSTOMOBJECT SupSkiFun.SMTPSecureEnabledInfo
.LINK
https://www.powershellgallery.com/packages/HPERedfishCmdlets/1.0.0.2
.EXAMPLE
Get AlertMailSMTPSecureEnabled setting for one host:
$creds = Get-Credential
Get-AlertMailSMTPSecure -ILO MyHost-ilo.example.com -Credential $creds
.EXAMPLE
Get AlertMailSMTPSecureEnabled setting for two hosts, returning object into a variable,	sending a test email when complete:
$creds = Get-Credential
$MyVar = Get-AlertMailSMTPSecure -ILO Host01ilo , Host02ilo -Credential $creds -TestEmail
.NOTES
These functions were written as a "stop-gap" measure until HPEiLOCmdlets contains an update
to the Get/Set HPEilLOAlertMailSetting.  The current version (2.0.0.1) of the HPEilLOAlertMailSetting Cmdlets
appears to use an ILO4 class, which doesn't contain a property for AlertMailSMTPSecure.  This is a property
on ILO5 which can be read / altered via REST/Redish.  Ideally this "function"-ality (ugh) will be
incorporated in a future HPe release, obviating the need for the functions in this module.
These functions were written and tested using HPERedfishCmdlets Version 1.0.0.2.
#>
function Get-AlertMailSMTPSecure
{
    [CmdletBinding()]
	param
    (
        [Parameter(Mandatory = $true)]
        [string[]]$ILO,
		[Alias("Name")]

		[Parameter(Mandatory = $true)]
        [pscredential]$Credential,

		[Parameter(Mandatory = $false)]
		[switch]$DisableCertificateAuthentication,

		[Parameter(Mandatory = $false)]
		[switch]$TestEmail

	)

	Begin
	{
		if ($DisableCertificateAuthentication)
		{
			$b = Test-HPERedfishCertificateAuthentication
			if($b)
			{
				Disable-HPERedfishCertificateAuthentication
			}
		}
	}

	Process
	{
		foreach ($i in $ilo)
		{
			#Error Checking Anyone?
  			$c = Connect-HPERedfish -Address $i -Credential $credential
			$m = Get-HPERedfishDataRaw -Odataid '/redfish/v1/managers/' -Session $c
			# Loop for more members?
			$md = Get-HPERedfishDataRaw -Odataid $m.Members.'@odata.id' -Session $c
			$iv = $md.FirmwareVersion.Split()[1]

			if($iv -ne "5")
			{
				$loopobj = [pscustomobject]@{
					HostName = $i
					AlertMailSMTPSecureEnabled = "Not attempted - ILO $iv detected"
				}
				$loopobj.PSObject.TypeNames.Insert(0,'SupSkiFun.SMTPSecureEnabledInfo')
				$loopobj
  			}
			else
			{
				$ns = Get-HPERedfishDataRaw -Odataid $md.NetworkProtocol.'@odata.id' -Session $c
				$g = Get-HPERedfishDataRaw -Odataid $md.NetworkProtocol.'@odata.id' -Session $c
				$loopobj = [pscustomobject]@{
					HostName = $i
					AlertMailSMTPSecureEnabled = ($g.oem.hpe.AlertMailSMTPSecureEnabled).ToString().Trim()
  				}
				$loopobj.PSObject.TypeNames.Insert(0,'SupSkiFun.SMTPSecureEnabledInfo')
				$loopobj
			}

			if($TestEmail -and $iv -eq "5")
			{
				Invoke-HPERedfishAction -Odataid $ns.Oem.Hpe.Actions.'#HpeiLOManagerNetworkService.SendTestAlertMail'.target -Session $c |
					Out-Null
			}

			Disconnect-HPERedfish -Session $c
		}
	}

	End
	{
		if($b)
		{
			Enable-HPERedfishCertificateAuthentication
		}
	}
}

<#
.SYNOPSIS
Enables or Disables HPe ILO SMTP Secure Email Connection Setting on ILO 5.
.DESCRIPTION
Enables or Disables HPe ILO SMTP Secure Email Connection Setting on ILO 5 only.
Not Applicable to ILO 4 and lower; will return Not Attempted.  Future:  Will need to modify for ILO 6.
Returns an object of Hostname, Result, and AlertMailSMTPSecureEnabled.
Requires Credential Object generated from Get-Credential.
Requires Module HPERedfishCmdlets: https://www.powershellgallery.com/packages/HPERedfishCmdlets/1.0.0.2
Optionally sends a test email when complete.  If enabling secure, the mail relay must accept secure connections.
.PARAMETER ILO
FQDN of ILO(s).
.PARAMETER Credential
PSCredential generated from Get-Credential.
.PARAMETER State
State to set AlertMailSMTPSecureEnabled.  Enabled or Disabled.
.PARAMETER DisableCertificateAuthentication
If this switch parameter is present then server certificate authentication is disabled for the execution of this cmdlet. If not present it will execute
according to the global certificate authentication setting. The default is to authenticate server certificates. See Enable-HPERedfishCertificateAuthentication
and Disable-HPERedfishCertificateAuthentication to set the per PowerShell session default.
.PARAMETER TestEmail
Use if a post configuration test email is desired.
.OUTPUTS
PSCUSTOMOBJECT SupSkiFun.SMTPSecureEnabledInfo
.LINK
https://www.powershellgallery.com/packages/HPERedfishCmdlets/1.0.0.2
.EXAMPLE
Set AlertMailSMTPSecureEnabled for one host to true (enabled):
$creds = Get-Credential
Set-AlertMailSMTPSecure -ILO MyHost-ilo.example.com -Credential $creds -State Enabled
.EXAMPLE
Set AlertMailSMTPSecureEnabled for two hosts to false (disabled), returning object into a variable,	sending a test email when complete:
$creds = Get-Credential
$MyVar = Set-AlertMailSMTPSecure -ILO Host01ilo , Host02ilo -Credential $creds -State Disabled -TestEmail
.NOTES
These functions were written as a "stop-gap" measure until HPEiLOCmdlets contains an update
to the Get/Set HPEilLOAlertMailSetting.  The current version (2.0.0.1) of the HPEilLOAlertMailSetting Cmdlets
appears to use an ILO4 class, which doesn't contain a property for AlertMailSMTPSecure.  This is a property
on ILO5 which can be read / altered via REST/Redish.  Ideally this "function"-ality (ugh) will be
incorporated in a future HPe release, obviating the need for the functions in this module.
These functions were written and tested using HPERedfishCmdlets Version 1.0.0.2.
#>
function Set-AlertMailSMTPSecure
{
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact='high')]
	param
    (
        [Parameter(Mandatory = $true)]
        [string[]]$ILO,
		[Alias("Name")]

		[Parameter(Mandatory = $true)]
        [pscredential]$Credential,

		[Parameter(Mandatory = $true)]
		[ValidateSet("Enabled" , "Disabled")]
		[string]$State,

		[Parameter(Mandatory = $false)]
		[switch]$DisableCertificateAuthentication,

		[Parameter(Mandatory = $false)]
		[switch]$TestEmail
	)

    Begin
    {
		if($state -eq "Enabled")
		{
			$s = $true
		}
		elseif($state -eq "Disabled")
		{
			$s = $false
		}
		else
		{
			Write-Output "State to set undetermined.  Terminating."
		}

		if ($DisableCertificateAuthentication)
		{
			$b = Test-HPERedfishCertificateAuthentication
			if($b)
			{
				Disable-HPERedfishCertificateAuthentication
			}
		}

		$z = @{"AlertMailSMTPSecureEnabled" = $s}
		$y = @{"Hpe" = $z}
		$x = @{"Oem" = $y }
	}

	Process
	{
		foreach ($i in $ilo)
		{
			#Error Checking At Some Point
			if($PSCmdlet.ShouldProcess("$i to $($state)"))
			{
  				$c = Connect-HPERedfish -Address $i -Credential $credential
				$m = Get-HPERedfishDataRaw -Odataid '/redfish/v1/managers/' -Session $c
				$md = Get-HPERedfishDataRaw -Odataid $m.Members.'@odata.id' -Session $c  # Loop for more members?
				$iv = $md.FirmwareVersion.Split()[1]

				if($iv -ne "5")
				{
					$loopobj = [pscustomobject]@{
						HostName = $i
						Result = "Not Attempted; ILO $iv detected"
						AlertMailSMTPSecureEnabled = "Only Valid for ILO 5"
					}
					$loopobj.PSObject.TypeNames.Insert(0,'SupSkiFun.SMTPSecureEnabledInfo')
					$loopobj
  				}
				else
				{
					$ns = Get-HPERedfishDataRaw -Odataid $md.NetworkProtocol.'@odata.id' -Session $c
					$r = Set-HPERedfishData -Odataid $ns.'@odata.id' -Setting $x -Session $c
					$g = Get-HPERedfishDataRaw -Odataid $md.NetworkProtocol.'@odata.id' -Session $c
					$loopobj = [pscustomobject]@{
						HostName = $i
						Result = ($r.error.'@Message.ExtendedInfo').MessageId.ToString().Trim()
						AlertMailSMTPSecureEnabled = ($g.oem.hpe.AlertMailSMTPSecureEnabled).ToString().Trim()
  					}
					$loopobj.PSObject.TypeNames.Insert(0,'SupSkiFun.SMTPSecureEnabledInfo')
					$loopobj
				}

				if($TestEmail -and $iv -eq "5")
				{
					Invoke-HPERedfishAction -Odataid $ns.Oem.Hpe.Actions.'#HpeiLOManagerNetworkService.SendTestAlertMail'.target -Session $c |
						Out-Null
				}

				Disconnect-HPERedfish -Session $c
			}
		}
	}

	End
	{
		if($b)
		{
			Enable-HPERedfishCertificateAuthentication
		}
	}
}

<#.Synopsis
Returns an object of hard drives from HPe servers.
.DESCRIPTION
Returns an object of hard drives from HPe servers with model, serial, type, firmware, capacity, location, state and status.
Requires HPe cmdlets Connect-HPEiLO & Get-HPEiLOSmartArrayStorageController from module HPEiLOCmdlets; see https://github.com/hewlettpackard/
Requires providing ILO credentials.  Optimally use $MyCreds = Get-Credential to generate credentials.
.PARAMETER Server
Mandatory.  Server ILO(s) to query. Either use the ILO hostname or IP.
.PARAMETER Credentials
Mandatory.  For ILO access.  Optimally use $MyCreds = Get-Credential to generate credentials.
.OUTPUTS
[pscustomobject] SupSkiFun.HPeDriveInfo
.LINK
https://github.com/hewlettpackard/
.EXAMPLE
Return all hard drives from a server into an object using the ILO name:
$MyCreds = Get-Credential
$MyObj = Get-HardDrive -Server MyHost-ilo.MyPlace.Org -Credential $MyCreds
.EXAMPLE
Return all hard drives from a server into an object using the ILO IP and Get-HardDrive alias (ghhd):
$MyCreds = Get-Credential
$MyObj = ghhd -Server 172.16.16.16 -Credential $MyCreds
#>
function Get-HardDrive
{
    [CmdletBinding()]
    [Alias("ghhd")]
    param
    (
        [Parameter(Mandatory=$true,
			HelpMessage="Enter one or more server names",
			ValueFromPipelineByPropertyName=$true
		)]
		[Alias("ComputerName","IP")]
        [array]$Server,

		[Parameter(Mandatory=$true,
			HelpMessage="Pipe in Credentials",
			ValueFromPipeline=$true
		)]
		[pscredential]$Credential

	)

    Begin
    {
		$module = "HPEiLOCmdlets"
		$errmsg = " is required.  See https://github.com/hewlettpackard/"
		if(-not (Get-Command -Module $module -ErrorAction SilentlyContinue))
			{
				Write-Output "Module $module $errmsg"
				break
			}
    }

    Process
    {
		$connc = Connect-HPEiLO -IP $server -Credential $Credential -DisableCertificateAuthentication
		$storc = Get-HPEiLOSmartArrayStorageController -Connection $connc
		foreach ($chose in $storc)
		{
			foreach ($drive in $chose.Controllers.LogicalDrives.DataDrives)
			{
				$loopobj = [pscustomobject]@{
					Hostname = $chose.HostName
					Model = $drive.Model
					Serial = $drive.SerialNumber
					Firmware = $drive.FirmwareVersion
					Type = $drive.MediaType
					Size = $drive.CapacityGB
					State = $drive.State
					Health = $drive.Status.Health
					Location = $drive.Location
				}
				$loopobj
				$loopobj.PSObject.TypeNames.Insert(0,'SupSkiFun.DriveInfo')
			}
		}
    }
}