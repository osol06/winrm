# Check PowerShell Version
$ps_ver = $PSVersionTable.PSVersion.Major
if ( $ps_ver -lt 3 )
{
  Write-Host "NG: You must update PowerShell." -ForegroundColor Red
  Write-Host "PowerShell version : " $ps_ver -ForegroundColor Red
  Write-Host "PowerShell 3.0 or higher is needed for most provided Ansible modules." -ForegroundColor Red
  exit 1
}
Write-Host "OK: Check Power Shell version is 3.0 or higher." -ForegroundColor Green

# Remove SSL listener
$selectorset = @{
    Transport = "HTTPS"
    Address = "*"
}
Remove-WSManInstance -ResourceURI 'winrm/config/Listener' -SelectorSet $selectorset

# Disable Basic Authentication
Write-Host "Disabling basic auth support."
winrm set winrm/config/service/auth '@{Basic="false"}'

# Remove Firewall Rule
Write-Host "Removing firewall rule to allow WinRM HTTPS."
Remove-NetFirewallRule -DisplayName "Allow WinRM HTTPS"

Write-Host "Finalize tool is success." -ForegroundColor Green

exit 0