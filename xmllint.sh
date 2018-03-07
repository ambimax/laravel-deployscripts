#!/usr/bin/env bash

FOLDER=${1:-'.'}

function error_exit {
	echo "$1" 1>&2
	exit 1
}

if [ ! -d $FOLDER ] ; then
    error_exit "Invalid dir"
fi

command_exists () {
    type "$1" &> /dev/null ;
}

FILES=`find $FOLDER -type f -name "*.xml" -not -path "*/vendor/*"`

TMP_FILE=/tmp/xmllint.tmp
touch $TMP_FILE;

if command_exists xmllint ; then
    for i in $FILES; do
        md5=($(md5sum $i));
        if grep -Fxq "$md5" $TMP_FILE; then
            continue;
        fi
            xmllint --noout "$i" || error_exit "Unable to parse file '$i'"
            echo $md5 >> $TMP_FILE
    done
else
    echo "Could not find xmllint. Using PHP instead..."
    for i in $FILES; do
        md5=($(md5sum $i));
        if grep -Fxq "$md5" $TMP_FILE; then
            continue;
        else
            php -r "if (@simplexml_load_file('$i') === false) exit(1);" || error_exit "Unable to parse file '$i'"
            echo $md5 >> $TMP_FILE
        fi
    done
fi

echo "No syntax errors detected in $FOLDER"