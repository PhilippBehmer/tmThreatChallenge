#!/bin/bash

dsmAdmin='t0Admin'
dsmConsolePort='443'
dsmT0Password=${1}
mtActivationCode=${2}
dsmFqdn=${3}
dsStackName=${4}





logfile=${dsStackName}.log


echo "Starting DSM Configuration" >> ${logfile} 2>&1
echo "Waiting for Stack build to complete" >> ${logfile}  2>&1

dsStackStatus=$(aws cloudformation describe-stacks --stack-name ${dsStackName} --query 'Stacks[].StackStatus' --output text)

until [ ${dsStackStatus} == "CREATE_COMPLETE" ]
do
    sleep 60
    dsStackStatus=$(aws cloudformation describe-stacks --stack-name ${dsStackName} --query 'Stacks[].StackStatus' --output text)
done

echo "Set DSM Route53 entry" >> ${logfile} 2>&1
../orchestration/setDsmRoute53.sh ${dsStackName} ${dsmFqdn}
echo "Set cert on public ELB"
##todo: remove hardcoded certificate
../orchestration/setDsmCert.sh ${dsStackName} "arn:aws:acm:us-east-1:030740019207:certificate/0f80dc13-a46c-4e67-8563-37286127ee5a"
echo "Wait 10 minutes for DNS" >> ${logfile} 2>&1
sleep 600
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

