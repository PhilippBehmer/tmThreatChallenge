#!/bin/bash
## createTenant <user> <pass> <fqdn> <port> <newTenantName> <newTenantPass>

username=$1
password=$2
dsmurl="$3:$4"
tenantName=$5
tenantAdminPassword="$6"

#echo -e "#####Login to DSM at ${dsmurl}\n"
tempDSSID=$(curl -ks -H "Content-Type: application/json" -X POST "https://${dsmurl}/rest/authentication/login/primary" -d '{"dsCredentials":{"userName":"'${username}'","password":"'${password}'"}}')
#echo -e "\n#### SID:"
#echo $tempDSSID

#echo -e "\n####Create tenant ${tenantName}\n"
createTenantResponse=$(curl -ks -H "Content-Type: application/xml" -X POST "https://${dsmurl}/rest/tenants" -d \
'<createTenantRequest>
  <createOptions>
    <adminAccount>MasterAdmin</adminAccount>
    <adminPassword>'${tenantAdminPassword}'</adminPassword>
    <adminEmail>MasterAdmin@ctf.labs.local</adminEmail>
  </createOptions>
  <tenantElement>
    <name>'${tenantName}'</name>
    <language>en</language>
    <country>US</country>
    <timeZone>US/Eastern"</timeZone>
  </tenantElement>
  <sessionId>'${tempDSSID}'</sessionId>
</createTenantRequest>')

#echo -e "\nCreateResponse:\n${createTenantResponse}\n"

tenantId=$(echo $createTenantResponse | xml_grep --text_only tenantID)
#echo "\n####Get tenant activation credentials"
tenantElement=$(curl -ks -H "Content-Type: application/xml" -X GET "https://${dsmurl}/rest/tenants/id/${tenantId}?sID=${tempDSSID}")


curl -k -X DELETE https://${dsmurl}/rest/authentication/logout?sID=$tempDSSID > /dev/null

unset tempDSSID
unset username
unset password

echo $tenantElement | xml_grep --text_only agentInitiatedActivationPassword
echo $tenantElement | xml_grep --text_only guid
