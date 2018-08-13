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
        WriteNetworkConfigs
        WriteOther
    } > config.json
    log "Created config.json"

    {
        WritePGConfig
    } > pgconfig.json
    log "Created pgconfig.json"

    {
        WriteAppConfig
    } > appconfig.json
    log "Created appconfig.json"
}

# Write network-configs
function WriteNetworkConfigs {
    echo "{
        \"network-configs\": {
            \"network-1\": {"
    WriteVersion
    WriteClient
    WriteChannels
    WriteOrganizations
    WritePeers
    WriteOrderers
    echo "           }"
    echo "        },"
}

# Write version
function WriteVersion {
    echo "                \"version\": \"1.0\","
}

# Write client
function WriteClient {
    # 使用第一个Peer组织的第一个Peer当做client
    IFS=', ' read -r -a PORGS <<< "$PEER_ORGS"
    echo "                \"client\": {
                    \"organization\": \"${PORGS[0]}\",
                    \"channel\": \"$CHANNEL_NAME\",
                    \"credentialStore\": {
                        \"path\": \"./tmp/credentialStore_Org1/credential\",
                        \"cryptoStore\": {
                            \"path\": \"./tmp/credentialStore_Org1/crypto\"
                        }
                    }
                },"
}

# Write channels
function WriteChannels {
    IFS=', ' read -r -a PORGS <<< "$PEER_ORGS"
    echo "                \"channels\": {
                    \"$CHANNEL_NAME\": {
                        \"peers\": {
                            \"peer1-${PORGS[0]}:7051\": {}
                        },
                        \"connection\": {
                            \"timeout\": {
                                \"peer\": {
                                    \"endorser\": "6000",
                                    \"eventHub\": "6000",
                                    \"eventReg\": "6000"
                                }
                            }
                        }
                    }
                },"
}

# Write organizations
function WriteOrganizations {
    IFS=', ' read -r -a ALLORGS <<< "$ORGS"
    echo "              \"organizations\": {"
    local COUNT=1
    for ORG in $ORGS ; do {
        initOrgVars $ORG
        echo "                  \"$ORG\": {
                    \"mspid\": \"$ORG_MSP_ID\",
                    \"fullpath\": false,
                    \"adminPrivateKey\": {
                        \"path\": \"$ORG_ADMIN_HOME/msp/keystore\"
                    },
                    \"signedCert\": {
                        \"path\": \"$ORG_ADMIN_HOME/msp/signcerts\"
                    }"
        if [ $COUNT -eq ${#ALLORGS[*]} ]; then
            echo "                  }"
        else
            echo "                  },"
        fi
        COUNT=$(($COUNT+1))
    }
    done
    echo "               },"
}

# Write peers
function WritePeers {
    echo "              \"peers\": {"
    IFS=', ' read -r -a PORGS <<< "$PEER_ORGS"
    local ORGCOUNT=1
    for ORG in $PEER_ORGS; do
        local COUNT=1
        while [[ "$COUNT" -le $NUM_PEERS ]]; do
            echo "                  \"peer$COUNT-$ORG:7051\": {
                        \"tlsCACerts\": {
                            \"path\": \"/$DATA/$ORG-ca-chain.pem\"
                        },
                        \"url\": \"grpcs://peer$COUNT-$ORG:7051\",
                        \"eventUrl\": \"grpcs://peer$COUNT-$ORG:7053\",
                        \"grpcOptions\": {
                            \"ssl-target-name-override\": \"peer$COUNT-$ORG\"
                        }"
            if [ $ORGCOUNT -eq ${#PORGS[*]} -a $COUNT -eq $NUM_PEERS ]; then
                echo "                  }"
            else
                echo "                  },"
            fi
            COUNT=$(($COUNT+1))
        done
        ORGCOUNT=$(($ORGCOUNT+1))
    done
    echo "              },"
}

# Write orderers
function WriteOrderers {
    echo "              \"orderers\": {"
    IFS=', ' read -r -a OORGS <<< "$ORDERER_ORGS"
    local ORGCOUNT=1
    for ORG in $ORDERER_ORGS; do
        local COUNT=1
        while [[ "$COUNT" -le $NUM_ORDERERS ]]; do
            echo "                  \"orderer$COUNT-$ORG:7050\": {
                        \"url\": \"grpcs://orderer$COUNT-$ORG:7050\""

            if [ $ORGCOUNT -eq ${#OORGS[*]} -a $COUNT -eq $NUM_ORDERERS ]; then
                echo "                  }"
            else
                echo "                  },"
            fi
            COUNT=$(($COUNT+1))
        done
    ORGCOUNT=$(($ORGCOUNT+1))
    done
    echo "              }"
}

# Write other
function WriteOther {
    echo "        \"keyValueStore\": \"/tmp/fabric-client-kvs\",
	\"configtxgenToolPath\": \"fabric-path/fabric-samples/bin\",
	\"eventWaitTime\": \"30000\",
        \"synchBlocksTime\": \"3\",
	\"license\": \"Apache-2.0\"
}"
}

# Write PG config
function WritePGConfig {
    echo "{
	\"pg\": {
		    \"host\": \"explorer-db\",
		    \"port\": \"$DATABASE_PORT\",
		    \"database\": \"$DATABASE_NAME\",
		    \"username\": \"$DATABASE_USERNAME\",
		    \"passwd\": \"$DATABASE_PASSWD\"
	}
}"
}

# Write app config
function WriteAppConfig {
    echo "{
    \"host\": \"localhost\",
    \"port\": \"8080\",
    \"license\": \"Apache-2.0\",
    \"version\": \"$FABRIC_VERSION\"
}"
}

main
