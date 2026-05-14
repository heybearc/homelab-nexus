#Requires -RunAsAdministrator
<#
.SYNOPSIS
  Import the homelab RDP server public certificate from C:\temp into the local machine trust stores so RDP clients stop CA warnings.

.DESCRIPTION
  Expects: C:\temp\rdp-listener-homelab.cer (public cert only, no private key).
  Imports into LocalMachine\TrustedPeople. Use -AlsoRootStore if mstsc still warns after import.

  Must run elevated (Run as administrator).

.PARAMETER CertPath
  Full path to the .cer file. Default: C:\temp\rdp-listener-homelab.cer

.PARAMETER AlsoRootStore
  Also import into LocalMachine\Root (some RDP builds stop prompting only with this). Prefer TrustedPeople alone when possible.

.NOTES
  Pair with: scripts/windows/rdp-listener-custom-cert.ps1 (server) and distribute the same exported .cer to clients.
#>
[CmdletBinding()]
param(
    [string] $CertPath = 'C:\temp\rdp-listener-homelab.cer',
    [switch] $AlsoRootStore
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $CertPath -PathType Leaf)) {
    throw "Certificate file not found: $CertPath`nCopy rdp-listener-homelab.cer to C:\temp (or pass -CertPath)."
}

$leaf = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($CertPath)
Write-Host "Importing certificate:"
Write-Host "  Subject: $($leaf.Subject)"
Write-Host "  Thumbprint: $($leaf.Thumbprint)"
Write-Host "  Path: $CertPath"
$leaf.Dispose()

Write-Host ''
Write-Host '--- TrustedPeople (LocalMachine) ---'
Import-Certificate -FilePath $CertPath -CertStoreLocation 'Cert:\LocalMachine\TrustedPeople' | Out-Null
Write-Host 'OK: imported to Cert:\LocalMachine\TrustedPeople'

if ($AlsoRootStore) {
    Write-Host ''
    Write-Host '--- Trusted Root (LocalMachine) ---'
    Import-Certificate -FilePath $CertPath -CertStoreLocation 'Cert:\LocalMachine\Root' | Out-Null
    Write-Host 'OK: imported to Cert:\LocalMachine\Root'
}

Write-Host ''
Write-Host 'Done. Restart Microsoft Remote Desktop (or reboot) if the warning still appears once.'
