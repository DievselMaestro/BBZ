$AdminSiteURL = "https://bbzolten-admin.sharepoint.com/"
$Prefix = "qvo"
 
#Get Credentials to connect to SharePoint Admin Center
$Cred = Get-Credential
 
#Connect to SharePoint Online Admin Center
Connect-SPOService -Url $AdminSiteURL -credential $Cred
 
#Loop through all user OneDrive sites and delete them
for ($i = 1; $i -le 300; $i++) {
    if ($i -lt 10) {
        $username = $Prefix + "0$i"
    }
    else {
        $username = $Prefix + $i
    }
    $OneDriveSiteUrl = "https://bbzolten-my.sharepoint.com/personal/$username`_bbzolten_ch"
    Write-Host "Deleting OneDrive site collection for user $username..."
    Remove-SPOSite -Identity $OneDriveSiteUrl -Confirm:$false
}
 
Write-Host "All OneDrive site collections deleted successfully"
