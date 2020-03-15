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

# Initialize Proxy Server
$del_proxy = Read-Host 'Is Proxy Server Information initialized ? This is only VIF. (y/n) [n] '
if ( $del_proxy -eq 'y')
{
  $adm_uid    = whoami /user | Select-String 'Administrator'
  $adm_uid    = (-split $adm_uid)[1]
  $reg_key    = "Registry::HKEY_USERS\$adm_uid\Software\Microsoft\Windows\CurrentVersion\Internet Settings"
  foreach ( $entry in 'ProxyOverride', 'ProxyServer', 'ProxyEnable' )
  {
    if ( Test-Path $reg_key )
    {
      $retReg = (Get-ItemProperty $reg_key).$entry
      if ( $retReg -ne $null )
      {
        Remove-ItemProperty -Path $reg_key -Name $entry
        Write-Host "Initialize config in $entry : $retReg"
      }
      else
      {
        Write-Host "$entry is already initialized." -ForegroundColor Cyan
      }
    }
    else
    {
      Write-Host "$reg_key is not exsit." -ForegroundColor Red
    }
  }
  Write-Host "OK: Initialize proxy server setting." -ForegroundColor Green
}
else
{
  Write-Host "Not initialize proxy server setting by user."
}

Write-Host "Finalize tool is success." -ForegroundColor Green

exit 0