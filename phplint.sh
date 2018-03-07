#!/usr/bin/env bash

FOLDER=${1:-'.'}

function error_exit {
	echo "$1" 1>&2
	exit 1
}

if [ ! -d $1 ] ; then
    error_exit "Invalid dir"
fi

FILES=`find $FOLDER -type f \( -name '*.php' -o -name '*.phtml' \) -not -path "*/vendor/*"`


TMP_FILE=/tmp/phplint.tmp
touch $TMP_FILE;

for i in $FILES; do

    md5=($(md5sum $i));
    if grep -Fxq "$md5" $TMP_FILE; then
        continue
    fi

    php -l "$i" >/dev/null 2>&1 || error_exit "Unable to parse file '$i'"
    echo $md5 >> $TMP_FILE
done

echo "No syntax errors detected in $FOLDER"