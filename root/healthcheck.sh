#!/bin/sh -e

TARGET=localhost
CURL_OPTS="--connect-timeout 30 --max-time 200 --silent --show-error --fail"

curl ${CURL_OPTS} "http://${TARGET}:8080" >/dev/null