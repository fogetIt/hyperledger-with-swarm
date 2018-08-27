#!/bin/bash
source utils.sh
: <<'COMMIT'
FABRIC_VERSION
COMMIT

check_fabric_tools ()
{
    tools=(cryptogen configtxgen configtxlator peer)
    for tool in ${tools[@]}; do
        if ! which $tool; then
            error_log "$tool not found. exiting"
            exit 1
        fi
    done
}
check_image_version ()
{
    local_version=$(configtxlator version | sed -ne 's/ Version: //p')
    info_log "local_version=${local_version}"
    info_log "image_version=${FABRIC_VERSION}"

    if [ "${local_version}" != "${FABRIC_VERSION}" ] ; then
        warn_log "Local fabric binaries and docker images are out of sync. This may cause problems."
    fi
}
check_fabric_tools
check_image_version
generate_certificates ()
{
    info_log "Generate certificates using cryptogen tool"
    cryptogen generate --config=./crypto-config.yaml --output=./crypto-config
}
generate_channel_artifacts ()
{
    cd channel-artifacts
    info_log "Generating Orderer Genesis block"
    configtxgen -profile orderersOrgGenesis -outputBlock ./genesis.block

    info_log "Generating channel configuration transaction 'channel.tx'"
    configtxgen -profile zjhlOrgChannel -outputCreateChannelTx ./channel.tx -channelID ${CHANNEL_NAME}

    info_log "Generating anchor peer update for zjhlMSP"
    configtxgen -profile zjhlOrgChannel -outputAnchorPeersUpdate ./zjhlMSPanchors.tx -channelID ${CHANNEL_NAME} -asOrg zjhlMSP
}
(
    cd ${FABRIC_CFG_PATH}
    generate_certificates
    generate_channel_artifacts
)