#!/bin/bash
# Add SendGrid DNS records to cloudigan.com via DC-01 Windows DNS

set -e

DC01_HOST="10.92.0.10"
DC01_USER="cory@cloudigan.com"
DNS_ZONE="cloudigan.com"

echo "Adding SendGrid DNS records to ${DNS_ZONE} via DC-01..."
echo ""

# Add 5 CNAME records
echo "Adding CNAME records..."
ssh ${DC01_USER}@${DC01_HOST} "powershell.exe -Command \"
Add-DnsServerResourceRecordCName -Name 'url3953' -HostNameAlias 'sendgrid.net' -ZoneName '${DNS_ZONE}' -ErrorAction SilentlyContinue;
Add-DnsServerResourceRecordCName -Name '61130637' -HostNameAlias 'sendgrid.net' -ZoneName '${DNS_ZONE}' -ErrorAction SilentlyContinue;
Add-DnsServerResourceRecordCName -Name 'em8063' -HostNameAlias 'u61130637.wl138.sendgrid.net' -ZoneName '${DNS_ZONE}' -ErrorAction SilentlyContinue;
Add-DnsServerResourceRecordCName -Name 's1._domainkey' -HostNameAlias 's1.domainkey.u61130637.wl138.sendgrid.net' -ZoneName '${DNS_ZONE}' -ErrorAction SilentlyContinue;
Add-DnsServerResourceRecordCName -Name 's2._domainkey' -HostNameAlias 's2.domainkey.u61130637.wl138.sendgrid.net' -ZoneName '${DNS_ZONE}' -ErrorAction SilentlyContinue;
Write-Host 'CNAME records added'
\""

echo "✅ CNAME records added"
echo ""

# Update DMARC TXT record
echo "Updating DMARC TXT record..."
ssh ${DC01_USER}@${DC01_HOST} "powershell.exe -Command \"
# Remove old DMARC record if exists
Remove-DnsServerResourceRecord -ZoneName '${DNS_ZONE}' -RRType 'TXT' -Name '_dmarc' -Force -ErrorAction SilentlyContinue;
# Add new DMARC record with SendGrid support
Add-DnsServerResourceRecord -ZoneName '${DNS_ZONE}' -TXT -Name '_dmarc' -DescriptiveText 'v=DMARC1; p=quarantine; rua=mailto:re+l6nzji6h0kd@dmarc.postmarkapp.com,mailto:cory@cloudigan.com; ruf=mailto:cory@cloudigan.com; fo=1; aspf=r; adkim=r';
Write-Host 'DMARC record updated'
\""

echo "✅ DMARC record updated"
echo ""

# Verify records
echo "Verifying DNS records..."
echo ""
echo "CNAME Records:"
dig CNAME url3953.cloudigan.com +short
dig CNAME em8063.cloudigan.com +short
dig CNAME s1._domainkey.cloudigan.com +short
echo ""
echo "DMARC Record:"
dig TXT _dmarc.cloudigan.com +short
echo ""

echo "✅ SendGrid DNS configuration complete!"
echo ""
echo "Next steps:"
echo "1. Wait 5-10 minutes for DNS propagation"
echo "2. Verify in SendGrid dashboard"
echo "3. Get SendGrid API key"
echo "4. Add to STANDBY container and test"
