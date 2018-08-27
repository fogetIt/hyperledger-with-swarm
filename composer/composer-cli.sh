#!/bin/sh
# composer card delete -c PeerAdmin@zjhl
# composer card delete -c zjhl-secret@forfaiting
set -e
DIR=$(pwd)
info_log ()
{
    echo -e "\033[32m=====> INFO: ${1}\033[0m"
}

set -x
info_log "Create PeerAdmin@zjhl.card!"
(cd fabric-config
    composer card create -u PeerAdmin -p ${DIR}/zjhl.json -k $(ls *_sk) -c Admin@zjhl.com-cert.pem -r PeerAdmin -r ChannelAdmin -f PeerAdmin@zjhl.card
    composer card import -f PeerAdmin@zjhl.card -c PeerAdmin@zjhl
)
composer card list

info_log "Generate and install forfaiting@0.0.1.bna!"
(cd forfaiting
    composer archive create -t dir -n .
    composer network install --card PeerAdmin@zjhl --archiveFile forfaiting@0.0.1.bna
)

info_log "Request to get a certificate and private key!"
composer identity request -c PeerAdmin@zjhl -u admin -s adminpw -d zjhl-secret
TIMESTAMP=$(date +%s)
info_log "Create zjhl-secret@forfaiting.card!"
(cd zjhl-secret
    composer network start -c PeerAdmin@zjhl -n forfaiting -V 0.0.1 -A zjhl-secret -C admin-pub.pem -o endorsementPolicyFile=${DIR}/endorsement-policy.json
    composer card create -u zjhl-secret -n forfaiting -p ${DIR}/zjhl.json -c admin-pub.pem -k admin-priv.pem
    composer card import -f zjhl-secret@forfaiting.card
)
composer card list
set +x
while [ $(($(date +%s) - ${TIMESTAMP})) -lt $((5 * 60)) ]; do
    sleep 5
done
set -x
composer network ping -c zjhl-secret@forfaiting
: <<'COMMIT'
composer participant add -c zjhl-secret@forfaiting.card -d '{"$class":...}'
composer identity issue -c zjhl-secret@forfaiting.card -f jo.card -u jdoe -a "resource:..."
composer card import -f jo.card
composer network ping -c jdoe@forfaiting
COMMIT