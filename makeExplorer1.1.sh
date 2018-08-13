#!/bin/bash
#
# Copyright IBM Corp. All Rights Reserved.
#
# SPDX-License-Identifier: Apache-2.0
#

#
# This script builds the docker compose file needed to run this sample.
#

set -e

SDIR=$(dirname "$0")
source $SDIR/scripts/env.sh

function main {
    {
        WriteNetworkConfig
        WriteChannel
        WriteOrderers
        WriteOther
    } > $SDIR/config.json
    log "Created config.json"
}

# Write network-config
function WriteNetworkConfig {
    echo "{
        \"network-config\": {"
    IFS=', ' read -r -a PORGS <<< "$PEER_ORGS"
    local ORGCOUNT=1
    for ORG in $PEER_ORGS; do
        local COUNT=1
        initOrgVars $ORG
        echo "                  \"$ORG\": {"
        echo "                      \"name\": \"$ORG\",
                      \"mspid\": \"$ORG_MSP_ID\","
            while [[ "$COUNT" -le $NUM_PEERS ]]; do
                initPeerVars $ORG $COUNT
                echo "                      \"$PEER_NAME\": {"
                echo "                          \"requests\": \"grpcs://$PEER_HOST:7051\",
			  \"events\": \"grpcs://$PEER_HOST:7053\",
			  \"server-hostname\": \"$PEER_NAME\",
			  \"tls_cacerts\": \"/$DATA/tls/$PEER_NAME-cli-client.crt\""
                echo "                      },"
                COUNT=$((COUNT+1))
            done
        echo "                      \"admin\": {
                                \"key\": \"$ORG_ADMIN_HOME/msp/keystore\",
                                \"cert\": \"$ORG_ADMIN_HOME/msp/signcerts\"
                            }"
        if [ "$ORGCOUNT" -eq ${#PORGS[*]} ]; then
            echo "                  }"
        else
            echo "                  },"
        fi
        ORGCOUNT=$((ORGCOUNT+1))
    done
    echo "        },"
}

# Write org
# Write channel
function WriteChannel {
    echo "        \"channel\": \"$CHANNEL_NAME\","
}
# Write orderers
function WriteOrderers {
    echo "        \"orderers\": ["
    IFS=', ' read -r -a OORGS <<< "$ORDERER_ORGS"
    local COUNT=1
    for ORG in $ORDERER_ORGS; do
        initOrgVars $ORG
        initOrdererVars $ORG $COUNT
        echo "              {
                    \"mspid\": \"$ORG_MSP_ID\",
                    \"server-hostname\": \"$ORDERER_HOST\",
                    \"requests\": \"grpcs://$ORDERER_HOST:7050\",
                    \"tls_cacerts\": \"/$DATA/tls/$ORDERER_NAME-cli-client.crt\""
        if [ $COUNT -eq ${#OORGS[*]} ];then
            echo "              }"
        else
            echo "              },"
        fi
        COUNT=$((COUNT+1))
    done

    echo "        ],"
}
# Write other
function WriteOther {
    echo "        \"keyValueStore\": \"/tmp/fabric-client-kvs\",
	\"configtxgenToolPath\": \"fabric-path/fabric-samples/bin\",
	\"SYNC_START_DATE_FORMAT\": \"YYYY/MM/DD\",
	\"syncStartDate\": \"2018/01/01\",
	\"eventWaitTime\": \"30000\",
	\"license\": \"Apache-2.0\",
	\"version\": \"1.1\"
}
    "
}
main