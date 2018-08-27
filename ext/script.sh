#!/bin/sh
export ARCH=`uname -m`
export NETWORK_NAME="ext_hyperledger"
export FABRIC_VERSION=${ARCH}-1.1.0
export COUCHDB_VERSION=${ARCH}-0.4.6