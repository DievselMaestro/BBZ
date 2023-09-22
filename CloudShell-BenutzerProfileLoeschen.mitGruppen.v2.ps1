param (
    [Parameter(Mandatory = $false)]
    [string[]]$ExcludeGroups
)

if (-not $ExcludeGroups -or $ExcludeGroups -ne "none") {
    Write-Host "Bitte geben Sie den Parameter -ExcludeGroups gefolgt von einer Liste von Gruppen an, die ausgeschlossen werden sollen." -ForegroundColor Green
    Write-Host "z.B. -ExcludeGroups Gruppe1, Gruppe2, Gruppe3, usw." -ForegroundColor Green
    Write-Host "" -ForegroundColor Green
    Write-Host "Um alle Benutzer zu löschen geben Sie: -ExcludeGroups none" -ForegroundColor Green
    Write-Host "" -ForegroundColor Green
    $pruefungsgruppenTabelle = @"
|-----------------|--------|--------|
| Prüfungsgruppen | von    | bis    |
|-----------------|--------|--------|
| KBS_112A        | qvo01  | qvo25  |
| KBS_112b        | qvo201 | qvo225 |
| KBS_a           | qvo26  | qvo50  |
| KBS_b           | qvo226 | qvo250 |
| KBS_01a         | qvo76  | qvo100 |
| KBS_01b         | qvo276 | qvo300 |
| KBS_03a         | qvo51  | qvo75  |
| KBS_03b         | qvo251 | qvo275 |
| GIBS_1          | qvo101 | qvo125 |
| GIBS_2          | qvo151 | qvo175 |
| GSBS_1          | qvo126 | qvo150 |
| GSBS_2          | qvo176 | qvo200 |
| QVI             | qvi01  | qvi100 |
|-----------------|--------|--------|
"@

    Write-Host $pruefungsgruppenTabelle -ForegroundColor Green
    exit
}

# Set the resource group names and host pool name
$ResourceGroupNameHostpool = "azurepl1-qvo"
$ResourceGroupNameVM = "AzurePL1-QVO-VM"
$HostPooolName = "QVO-Host"


# Define the groups and their associated QVO user ranges
$pruefungsgruppen = @{
    "KBS_112a" = @{ "von" = 01; "bis" = 25 }
    "KBS_112b" = @{ "von" = 201; "bis" = 225 }
    "KBS_a"    = @{ "von" = 26; "bis" = 50 }
    "KBS_b"    = @{ "von" = 226; "bis" = 250 }
    "KBS_01a"  = @{ "von" = 76; "bis" = 100 }
    "KBS_01b"  = @{ "von" = 276; "bis" = 300 }
    "KBS_03a"  = @{ "von" = 51; "bis" = 75 }
    "KBS_03b"  = @{ "von" = 251; "bis" = 275 }
    "GIBS_1"   = @{ "von" = 101; "bis" = 125 }
    "GIBS_2"   = @{ "von" = 151; "bis" = 175 }
    "GSBS_1"   = @{ "von" = 126; "bis" = 150 }
    "GSBS_2"   = @{ "von" = 176; "bis" = 200 }
    "QVI"      = @{ "von" = 01; "bis" = 100 }    
}


# Set the Azure context to the specified subscription
Set-AzContext -SubscriptionId 16e4f728-62c1-4afd-b90e-5c0ee167bf1f

#Alter Befehl
#$VMHost = Get-AzVM -ResourceGroupName  $ResourceGroupNameVM

# Get a list of session hosts from the specified host pool
$VMHost = Get-AzWvdSessionHost -HostPoolName $HostPooolName -ResourceGroupName $ResourceGroupNameHostpool

# Remove the "QVO-Host/" prefix and ".bbzo.local" suffix from each host name
$VMHost = $VMHost.Name -replace 'QVO-Host/', ''
$VMHost = $VMHost -replace '\.bbzo\.local', ''

# Loop through each session host
foreach ($WVDHost in $VMHost) {

    # Check if the VM is running and start it if it is not
    $VM = Get-AzVM -Name $WVDHost -ResourceGroupName $ResourceGroupNameVM -Status
    if ($VM.Statuses[1].Code -ne 'PowerState/running') {
        Write-Host "Starting VM:" $WVDHost
        Start-AzVM -Name $WVDHost -ResourceGroupName $ResourceGroupNameVM
    }

    
    # Connect to the host and run the script
    Write-Host "Connecting to Host:" $WVDHost
    Invoke-AZVMRunCommand -CommandId 'RunPowerShellScript' -VMName $WVDHost -ResourceGroupName $ResourceGroupNameVM -Parameter $pruefungsgruppen -ScriptString {
        # Define the list of accounts whose profiles must not be deleted
        $ExcludedUsers = "Public", "admin", "adminqvo", "administrator"

        # Iterate through the ExcludeGroups
        foreach ($QVOGruppenname in $ExcludeGroups) {
            # Check if the group exists in $pruefungsgruppen
            if ($pruefungsgruppen.ContainsKey($QVOGruppenname)) {
                for ($i = $pruefungsgruppen[$QVOGruppenname]["von"]; $i -le $pruefungsgruppen[$QVOGruppenname]["bis"]; $i++) {
                    $username = "qvo" + $i.ToString()
                    $ExcludedUsers += $username
                }
            }
            elseif ($QVOGruppenname -eq "QVI") {
                for ($i = $pruefungsgruppen["QVI"]["von"]; $i -le $pruefungsgruppen["QVI"]["bis"]; $i++) {
                    $username = "qvi" + $i.ToString()
                    $ExcludedUsers += $username
                }
            }
        }

        # Get a list of local profiles older than 0 days and not in use
        $LocalProfiles = Get-WMIObject -class Win32_UserProfile | Where-Object { (!$_.Special) -and (!$_.Loaded) -and ($_.ConvertToDateTime($_.LastUseTime) -lt (Get-Date).AddDays(-0)) }
        
        # Loop through each local profile and delete it if it is not excluded
        foreach ($LocalProfile in $LocalProfiles) {
            if (!($ExcludedUsers -like $LocalProfile.LocalPath.Replace("C:\Users\", ""))) {
                $LocalProfile | Remove-WmiObject
                Write-Host $WVDHost.Name, $LocalProfile.LocalPath, "profile deleted" -ForegroundColor Magenta
                #$Output += $WVDHost.Name, $LocalProfile.LocalPath, "profile deleted" 
            }
        }
    }
        
}
