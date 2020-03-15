Function New-LegacySelfSignedCert
{
    Param (
        [string]$SubjectName,
        [int]$ValidDays = 1095
    )

    $name = New-Object -COM "X509Enrollment.CX500DistinguishedName.1"
    $name.Encode("CN=$SubjectName", 0)

    $key = New-Object -COM "X509Enrollment.CX509PrivateKey.1"
    $key.ProviderName = "Microsoft RSA SChannel Cryptographic Provider"
    $key.KeySpec = 1
    $key.Length = 4096
    $key.SecurityDescriptor = "D:PAI(A;;0xd01f01ff;;;SY)(A;;0xd01f01ff;;;BA)(A;;0x80120089;;;NS)"
    $key.MachineContext = 1
    $key.Create()

    $serverauthoid = New-Object -COM "X509Enrollment.CObjectId.1"
    $serverauthoid.InitializeFromValue("1.3.6.1.5.5.7.3.1")
    $ekuoids = New-Object -COM "X509Enrollment.CObjectIds.1"
    $ekuoids.Add($serverauthoid)
    $ekuext = New-Object -COM "X509Enrollment.CX509ExtensionEnhancedKeyUsage.1"
    $ekuext.InitializeEncode($ekuoids)

    $cert = New-Object -COM "X509Enrollment.CX509CertificateRequestCertificate.1"
    $cert.InitializeFromPrivateKey(2, $key, "")
    $cert.Subject = $name
    $cert.Issuer = $cert.Subject
    $cert.NotBefore = (Get-Date).AddDays(-1)
    $cert.NotAfter = $cert.NotBefore.AddDays($ValidDays)
    $cert.X509Extensions.Add($ekuext)
    $cert.Encode()

    $enrollment = New-Object -COM "X509Enrollment.CX509Enrollment.1"
    $enrollment.InitializeFromRequest($cert)
    $certdata = $enrollment.CreateRequest(0)
    $enrollment.InstallResponse(2, $certdata, 0, "")

    # extract/return the thumbprint from the generated cert
    $parsed_cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2
    $parsed_cert.Import([System.Text.Encoding]::UTF8.GetBytes($certdata))

    return $parsed_cert.Thumbprint
}

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

# Make sure there is a SSL listener.
$SubjectName = $env:COMPUTERNAME
$CertValidityDays = 1095
$listeners = Get-ChildItem WSMan:\localhost\Listener
if (!($listeners | Where {$_.Keys -like "TRANSPORT=HTTPS"}))
{
    # We cannot use New-SelfSignedCertificate on 2012R2 and earlier
    $thumbprint = New-LegacySelfSignedCert -SubjectName $SubjectName -ValidDays $CertValidityDays
    Write-Host "Self-signed SSL certificate generated; thumbprint: $thumbprint"

    # Create the hashtables of settings to be used.
    $valueset = @{
        Hostname = $SubjectName
        CertificateThumbprint = $thumbprint
    }

    $selectorset = @{
        Transport = "HTTPS"
        Address = "*"
    }

    Write-Host "Enabling SSL listener."
    New-WSManInstance -ResourceURI 'winrm/config/Listener' -SelectorSet $selectorset -ValueSet $valueset
}
else
{
    Write-Host "SSL listener is already active."
}

# Check for basic authentication.
$basicAuthSetting = Get-ChildItem WSMan:\localhost\Service\Auth | Where {$_.Name -eq "Basic"}
if (($basicAuthSetting.Value) -eq $false)
{
    Write-Host "Enabling basic auth support."
    winrm set winrm/config/service/auth '@{Basic="true"}'
}
else
{
    Write-Host "Basic auth is already enabled."
}

# Configure firewall to allow WinRM HTTPS connections.
$fwtest1 = netsh advfirewall firewall show rule name="Allow WinRM HTTPS"
$fwtest2 = netsh advfirewall firewall show rule name="Allow WinRM HTTPS" profile=any
if ($fwtest1.count -lt 5)
{
    Write-Host "Adding firewall rule to allow WinRM HTTPS."
    netsh advfirewall firewall add rule profile=any name="Allow WinRM HTTPS" dir=in localport=5986 protocol=TCP action=allow
}
elseif (($fwtest1.count -ge 5) -and ($fwtest2.count -lt 5))
{
    Write-Host "Updating firewall rule to allow WinRM HTTPS for any profile."
    netsh advfirewall firewall set rule name="Allow WinRM HTTPS" new profile=any
}
else
{
    Write-Host "Firewall rule already exists to allow WinRM HTTPS."
}

Write-Host "Ansible Prescript is success." -ForegroundColor Green


exit 0