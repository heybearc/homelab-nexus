#Requires -RunAsAdministrator
<#
.SYNOPSIS
  Create a homelab self-signed TLS certificate with explicit SANs and bind it to the RDP listener (RDP-tcp).

.DESCRIPTION
  Use on cloudy-renvis01 (or any session host) when RDP clients warn because the listener cert does not match
  Tailscale IP / MagicDNS / internal DNS names. Run elevated (local console, iDRAC, or a session that can survive
  TermService restart).

  After binding, connect using any SAN you included (e.g. 100.83.60.29 or cloudy-renvis01.tailb5a4e.ts.net).
  Clients may still warn once until they trust this self-signed cert (import exported .cer to Trusted Root),
  but name-mismatch warnings for those SANs should stop.

.PARAMETER DnsNames
  Additional dns= SAN entries (first is also used as Subject CN if PrimarySubjectCn is omitted).

.PARAMETER IpAddresses
  Additional ipaddress= SAN entries (Tailscale + LAN recommended).

.NOTES
  Homelab reference: documentation/CLOUDY-RENVIS01-MONITORING-SETUP.md
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [string] $PrimarySubjectCn = 'cloudy-renvis01.cloudigan.com',

    [string[]] $DnsNames = @(
        'cloudy-renvis01.cloudigan.com',
        'cloudy-renvis01.tailb5a4e.ts.net',
        'CLOUDY-RENVIS01',
        'cloudy-renvis01'
    ),

    [string[]] $IpAddresses = @(
        '100.83.60.29',
        '10.92.4.2'
    ),

    [int] $ValidityYears = 5,

    [string] $ExportCerPath = 'C:\Admin\rdp-listener-homelab.cer',

    [switch] $SkipTermServiceRestart
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-RdpListenerThumbprintHex {
    $ts = Get-CimInstance -Namespace 'root\cimv2\TerminalServices' `
        -ClassName 'Win32_TSGeneralSetting' `
        -Filter "TerminalName='RDP-tcp'"
    if (-not $ts) { throw 'Win32_TSGeneralSetting for RDP-tcp not found. Is Remote Desktop enabled?' }
    $h = $ts.SSLCertificateSHA1Hash
    if ([string]::IsNullOrWhiteSpace($h)) { return $null }
    return ($h -replace '\s', '').ToUpperInvariant()
}

Write-Host '--- Current RDP listener certificate thumbprint (SHA1 hex, if any) ---'
$oldThumb = Get-RdpListenerThumbprintHex
Write-Host ($(if ($oldThumb) { $oldThumb } else { '(empty / default auto cert)' }))

$sanParts = @()
foreach ($d in $DnsNames) {
    if (-not [string]::IsNullOrWhiteSpace($d)) { $sanParts += "DNS=$d" }
}
foreach ($ip in $IpAddresses) {
    if (-not [string]::IsNullOrWhiteSpace($ip)) { $sanParts += "IPAddress=$ip" }
}
$sanString = $sanParts -join '&'
$textExtensions = @(
    '2.5.29.37={text}1.3.6.1.5.5.7.3.1',
    "2.5.29.17={text}$sanString"
)

Write-Host '--- Creating certificate in LocalMachine\My ---'
Write-Host "Subject CN: CN=$PrimarySubjectCn"
Write-Host "SAN: $sanString"

if (-not $PSCmdlet.ShouldProcess("LocalMachine\My", 'New-SelfSignedCertificate for RDP listener')) {
    exit 0
}

$notAfter = (Get-Date).AddYears($ValidityYears)
$cert = New-SelfSignedCertificate `
    -Subject "CN=$PrimarySubjectCn" `
    -CertStoreLocation 'Cert:\LocalMachine\My' `
    -KeyAlgorithm RSA `
    -KeyLength 2048 `
    -HashAlgorithm SHA256 `
    -KeyExportPolicy Exportable `
    -NotAfter $notAfter `
    -TextExtension $textExtensions

$thumbHex = $cert.Thumbprint -replace '\s', ''
Write-Host "New certificate thumbprint: $thumbHex"

Write-Host '--- Verifying SAN on new cert ---'
$c = Get-Item "Cert:\LocalMachine\My\$($cert.Thumbprint)"
$c | Format-List Subject, Thumbprint, NotAfter
# Extensions display (Subject Alternative Name)
$c.Extensions | Where-Object { $_.Oid.Value -eq '2.5.29.17' } | ForEach-Object {
    Write-Host 'Raw SAN extension:'
    Write-Host $_.Format($false)
}

if ($ExportCerPath) {
    $exportDir = Split-Path -Parent $ExportCerPath
    if ($exportDir -and -not (Test-Path -LiteralPath $exportDir)) {
        New-Item -ItemType Directory -Path $exportDir -Force | Out-Null
    }
    Export-Certificate -Cert $c -FilePath $ExportCerPath -Type CERT | Out-Null
    Write-Host "Exported public cert to: $ExportCerPath (optional: import on clients as Trusted Root to silence CA warnings)"
}

Write-Host '--- Binding certificate to RDP-tcp via WMI/CIM ---'
$ts = Get-CimInstance -Namespace 'root\cimv2\TerminalServices' `
    -ClassName 'Win32_TSGeneralSetting' `
    -Filter "TerminalName='RDP-tcp'"

$ts.SSLCertificateSHA1Hash = $thumbHex
Set-CimInstance -InputObject $ts | Out-Null

Write-Host '--- Verify listener thumbprint ---'
(Get-RdpListenerThumbprintHex) | Write-Host

if (-not $SkipTermServiceRestart) {
    Write-Host '--- Restarting Remote Desktop Services (disconnects RDP; use console if needed) ---'
    Restart-Service TermService -Force
    Write-Host 'TermService restarted.'
}
else {
    Write-Host 'Skipped TermService restart (-SkipTermServiceRestart). Restart manually when safe.'
}

Write-Host ''
Write-Host 'Done. Connect with any SAN hostname or IP you included.'
Write-Host ''
Write-Host 'Optional client trust (removes self-signed CA warning):'
Write-Host '  Import the exported .cer into Trusted Root Certification Authorities on clients that should trust this homelab cert.'
Write-Host ''
Write-Host 'Rollback (elevated): set Win32_TSGeneralSetting.SSLCertificateSHA1Hash to the OLD thumbprint from the top of this output, then:'
Write-Host '  Restart-Service TermService -Force'
Write-Host ''
