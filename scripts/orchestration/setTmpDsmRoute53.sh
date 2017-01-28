#!/bin/bash
dnsname=${1}
ctrlDnsName=${2}


aws route53 change-resource-record-sets --cli-input-json '{
  "HostedZoneId": "Z54BUX0B2EC7C",
  "ChangeBatch" :{
    "Comment": "update DSM CNAME to ctrl for cert create",
    "Changes": [
      {
        "Action": "UPSERT", 
        "ResourceRecordSet": {
          "Name": "'${dnsname}'.",
          "Type": "CNAME",
          "AliasTarget": {
            "HostedZoneId": "Z54BUX0B2EC7C",
            "DNSName": "'${ctrlDnsName}'.",
            "EvaluateTargetHealth": false
          } 
        }
      }
    ]
  }
}'
