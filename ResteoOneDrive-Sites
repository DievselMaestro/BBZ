$AdminSiteURL = "https://bbzolten-admin.sharepoint.com/"
$Prefix = "qvi"
 
 #Connect to SharePoint Online Admin Center
Connect-SPOService -Url $AdminSiteURL


$Prefix = "qvi"
#Benutzer 01 bis 100
for ($i = 1; $i -le 100; $i++) {
    if ($i -lt 10) {
        $username = $Prefix + "0$i"
    }
    else {
        $username = $Prefix + $i
    }
    $OneDriveSiteUrl = Get-SPODeletedSite "https://bbzolten-my.sharepoint.com/personal/$username`_bbzolten_ch"
    Write-Host "Restoring OneDrive site collection for user $username..."    
    Restore-SPODeletedSite -Identity $OneDriveSiteUrl
}
