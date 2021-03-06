#!/bin/bash

dsmAdmin='t0Admin'
dsmConsolePort='443'
dsmT0Password=${1}
mtActivationCode=${2}
dsmFqdn=${3}
dsStackName=${4}
ctrlFqdn=${5}
baseDomain=${6}
baseDomainHostedZoneId=${7}

logfile=${dsStackName}.log

waitForDnsSync() {
    updateResponse="${1}"
    if [[ -z ${updateResponse} ]] || [[ "${updateResponse}" == *"error"* ]]
    then
        return
    fi
    changeID=$(echo ${updateResponse} | jq -r '.ChangeInfo.Id' | rev | cut -d"/" -f1 | rev)
    status=$(aws route53 get-change --id ${changeID} | jq -r '.ChangeInfo.Status')
        until [[ ${status} == 'INSYNC' ]]
        do
            sleep 20
            status=$(aws route53 get-change --id ${changeID} | jq -r '.ChangeInfo.Status')
        done
}

echo "Starting DSM Configuration" >> ${logfile} 2>&1

echo "Delete DSM Route53 record possibly leftover from previous build" >> ${logfile} 2>&1
updateResponse=$(../orchestration/delDsmRoute53.sh ${dsmFqdn} ${baseDomainHostedZoneId})
waitForDnsSync "${updateResponse}"

echo "Set DSM Route53 record to controller while we get a cert" >> ${logfile} 2>&1
updateResponse=$(../orchestration/setTmpDsmRoute53.sh ${dsmFqdn} ${ctrlFqdn} ${baseDomainHostedZoneId})
waitForDnsSync "${updateResponse}"

echo "Get new cert for DSM and upload to IAM" >> ${logfile} 2>&1
../orchestration/getCertForElb.sh ${dsmFqdn}
certArn=$(cat /home/ec2-user/variables/certArn)
echo "Delete DSM Route53 record to controller now that we have a cert" >> ${logfile} 2>&1
../orchestration/delTmpDsmRoute53.sh ${dsmFqdn} ${ctrlFqdn} ${baseDomainHostedZoneId}


echo "Waiting for Stack build to complete" >> ${logfile}  2>&1

dsStackStatus=$(aws cloudformation describe-stacks --stack-name ${dsStackName} --query 'Stacks[].StackStatus' --output text)

until [ ${dsStackStatus} == "CREATE_COMPLETE" ]
do
    sleep 60
    dsStackStatus=$(aws cloudformation describe-stacks --stack-name ${dsStackName} --query 'Stacks[].StackStatus' --output text)
done


echo "Set DSM Route53 entry" >> ${logfile} 2>&1
updateResponse=$(../orchestration/setDsmRoute53.sh ${dsStackName} ${dsmFqdn} ${baseDomainHostedZoneId})
echo "Set cert on public ELB"
../orchestration/setDsmCert.sh ${dsStackName} "${certArn}"
echo "Wait for DSM DNS SYNC" >> ${logfile} 2>&1
waitForDnsSync "${updateResponse}"
echo "Create EBT for T0" >> ${logfile} 2>&1
../dsm/ds10-rest-ebtCreate.sh ${dsmAdmin} ${dsmT0Password} ${dsmFqdn} ${dsmConsolePort}
echo "Modify Linux Server Policy in T0"
cd ../dotnet/
unzip -n wrkshop-ds-t0-policy-customization_centos.7-x64.zip
cd ../threatChallengeLaunch/
chmod +x ../dotnet/publish/wrkshop-ds-t0-policy-customization
../dotnet/publish/wrkshop-ds-t0-policy-customization ${dsmFqdn} ${dsmAdmin} ${dsmT0Password} "Linux Server"
echo "Enable MT" >> ${logfile} 2>&1
../dsm/ds10-rest-multiTenantConfigurationEnable.sh ${dsmAdmin} ${dsmT0Password} ${dsmFqdn} ${dsmConsolePort} ${mtActivationCode}
#echo "Create template tenant" >> ${logfile} 2>&1
#templateTenantId=$(../dsm/ds10-rest-createTemplateTenant.sh ${dsmAdmin} ${dsmPassword} ${dsmFqdn} ${dsmConsolePort})
#echo "Customize template tenant" >> ${logfile} 2>&1
#../dsm/ds10-customize-templateTenant.sh ${dsmAdmin} ${dsmPassword} ${dsmFqdn} ${dsmConsolePort}
#echo "Set template tenant" >> ${logfile} 2>&1
#../dsm/ds10-rest-setTemplateTenant.sh ${dsmAdmin} ${dsmPassword} ${dsmFqdn} ${dsmConsolePort} ${templateTenantId}

