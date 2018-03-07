#!/usr/bin/env bash

MY_PATH=`dirname $(readlink -f "$0")`
RELEASEFOLDER=$(readlink -f "${MY_PATH}/../../..")

if type "hhvm" &> /dev/null; then
    PHP_COMMAND=hhvm
    echo "Using HHVM for composer..."
else
    PHP_COMMAND=php
fi

function usage {
    echo "Usage:"
    echo " $0 -e <environment> [-r <releaseFolder>] [-s]"
    echo " -e Environment (e.g. production, staging, devbox,...)"
    echo " -s If set the project storage will not be imported"
    echo " -cc If set the cache will be cleared"
    echo ""
    exit $1
}

function error_exit {
	echo "$1" 1>&2
	exit 1
}

function usage_exit {
    echo "$1" 1>&2
    usage 1
}

function artisan {
    echo "$PHP_COMMAND ${RELEASEFOLDER}/artisan $1" 1>&2
    $PHP_COMMAND "${RELEASEFOLDER}/artisan $1"
}

while getopts 'e:r:s' OPTION ; do
case "${OPTION}" in
        e) ENVIRONMENT="${OPTARG}";;
        r) RELEASEFOLDER=`echo "${OPTARG}" | sed -e "s/\/*$//" `;; # delete last slash
        \?) echo; usage 1;;
    esac
done

if [ ! -f "${RELEASEFOLDER}/public/index.php" ] ; then error_exit "Invalid release folder"; fi

# Checking environment
if [ -z "${ENVIRONMENT}" ]; then error_exit "ERROR: Please provide an environment code (e.g. -e staging)"; fi
if [ ! -f "${RELEASEFOLDER}/.env.${ENVIRONMENT}" ]; then error_exit "ERROR: No .env.${ENVIRONMENT} file provided"; fi

echo
echo "Set .env file"
echo "-----------------------------"
cp -f "${RELEASEFOLDER}/.env.${ENVIRONMENT} ${RELEASEFOLDER}/.env"

echo
echo "Linking to shared directories"
echo "-----------------------------"
SHAREDFOLDER="${RELEASEFOLDER}/../../shared"
if [ ! -d "${SHAREDFOLDER}" ] ; then
    echo "Could not find '../../shared'. Trying '../../../shared' now"
    SHAREDFOLDER="${RELEASEFOLDER}/../../../shared";
fi

# Check if shared folders exist
if [ ! -d "${SHAREDFOLDER}" ] ; then error_exit "Shared directory ${SHAREDFOLDER} not found"; fi
if [ ! -d "${SHAREDFOLDER}/storage" ] ; then error_exit "Shared directory ${SHAREDFOLDER}/storage not found"; fi
if [ ! -d "${SHAREDFOLDER}/storage/app/public" ] ; then error_exit "Shared directory ${SHAREDFOLDER}/storage/app/public not found"; fi

# Check if symlink destination folders exist
if [ -d "${RELEASEFOLDER}/storage" ]; then error_exit "Found existing storage folder that shouldn't be there"; fi
if [ -d "${RELEASEFOLDER}/public/storage" ]; then error_exit "Found existing public/storage folder that shouldn't be there"; fi

# Create Symlinks
echo "Setting symlink (${RELEASEFOLDER}/storage) to shared storage folder (${SHAREDFOLDER}/storage)"
ln -s "${SHAREDFOLDER}/storage" "${RELEASEFOLDER}/storage"  || error_exit "Error while linking to shared storage directory"
echo "Setting symlink (${RELEASEFOLDER}/public/storage) to shared app/public folder (${SHAREDFOLDER}/storage/app/public)"
ln -s "${SHAREDFOLDER}/storage/app/public" "${RELEASEFOLDER}/public/storage"  || error_exit "Error while linking to shared storage directory"


echo
echo "Migrate Laravel"
echo "--------------"
artisan "migrate --force" || error_exit "Migration failed"

echo
echo "Cache and Optimize Laravel"
echo "--------------"
artisan "cache:clear"
artisan "config:cache"
artisan "route:cache"

echo
echo "Successfully completed installation."
echo
