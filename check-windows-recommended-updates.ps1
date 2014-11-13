$updateSession = new-object -com "Microsoft.Update.Session"
$allUpdates = $updateSession.CreateupdateSearcher().Search("IsInstalled=0 and Type='Software'").Updates
$recommendedUpdates = $allUpdates | ? { $_.AutoSelectOnWebSites }

if ($recommendedUpdates.Count -eq 0) {
	Write-Host "OK: no pending updates"
	exit 0
}
else {
	Write-Host "CRITICAL: "  (($recommendedUpdates).Title -Join "`n")
	exit 3
}