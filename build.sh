#!/usr/bin/env bash

function usage {
    echo "Usage:"
    echo " $0 -f <packageFilename> -b <buildNumber> [-g <gitRevision>] [-r <projectRootDir>]"
    echo " -f <packageFilename>    file name of the archive that will be created"
    echo " -b <buildNumber>        build number"
    echo " -g <gitRevision>        git revision"
    echo " -r <projectRootDir>     Path to the project dir. Defaults to current working directory."
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

PROJECTROOTDIR=$PWD

########## get argument-values
while getopts 'f:b:g:d:r:' OPTION ; do
case "${OPTION}" in
        f) FILENAME="${OPTARG}";;
        b) BUILD_NUMBER="${OPTARG}";;
        g) GIT_REVISION="${OPTARG}";;
        r) PROJECTROOTDIR="${OPTARG}";;
        \?) echo; usage 1;;
    esac
done

if [ -z ${FILENAME} ] ; then usage_exit "ERROR: No file name given (-f)"; fi
if [ -z ${BUILD_NUMBER} ] ; then usage_exit "ERROR: No build number given (-b)"; fi

cd ${PROJECTROOTDIR} || error_exit "Changing directory failed"

if [ ! -f 'composer.json' ] ; then error_exit "Could not find composer.json"; fi
if [ ! -f 'tools/composer.phar' ] ; then error_exit "Could not find composer.phar"; fi

if type "hhvm" &> /dev/null; then
    PHP_COMMAND=hhvm
    echo "Using HHVM for composer..."
else
    PHP_COMMAND=php
fi

TAR_COMMAND='tar -czf'

dpkg -l pigz > /dev/null 2>&1
if [ $? == '0' ]; then
    TAR_COMMAND='tar -I pigz -cf'
    echo "Using pigz for compression..."
fi

# Run composer
$PHP_COMMAND tools/composer.phar install --verbose --no-ansi --no-interaction --prefer-source --optimize-autoloader 2>&1 || error_exit "Composer failed"

# Some basic checks
if [ ! -f 'public/index.php' ] ; then error_exit "Could not find public/index.php"; fi
if [ ! -f 'routes/web.php' ] ; then error_exit "Could not find routes/web.php"; fi
if [ ! -f 'config/app.php' ] ; then error_exit "Could not find config/app.php"; fi
if [ ! -f 'bootstrap/app.php' ] ; then error_exit "Could not find bootstrap/app.php"; fi

# Write file: build.txt
echo "${BUILD_NUMBER}" > build.txt

# Write file: version.txt
echo "Build: ${BUILD_NUMBER}" > public/version.txt
echo "Build time: `date +%c`" >> public/version.txt
if [ ! -z ${GIT_REVISION} ] ; then echo "Revision: ${GIT_REVISION}" >> public/version.txt ; fi

# Set into maintenance mode
touch storage/framework/down

# Create package
if [ ! -d "artifacts/" ] ; then mkdir artifacts/ ; fi

tmpfile=$(tempfile -p build_tar_base_files_)

# In case tar_excludes.txt doesn't exist
if [ ! -f "config/tar_excludes.txt" ] ; then
    touch config/tar_excludes.txt
    echo '.git*' >> config/tar_excludes.txt
    echo 'composer.json' >> config/tar_excludes.txt
    echo 'composer.lock' >> config/tar_excludes.txt
fi

BASEPACKAGE="artifacts/${FILENAME}"
echo "Creating base package '${BASEPACKAGE}'"
${TAR_COMMAND} "${BASEPACKAGE}" --verbose \
    --exclude=./public/hot \
    --exclude=./public/storage \
    --exclude=./storage \
    --exclude=./artifacts \
    --exclude=./tmp \
    --exclude-from="config/tar_excludes.txt" . > $tmpfile || error_exit "Creating archive failed"

EXTRAPACKAGE=${BASEPACKAGE/.tar.gz/.extra.tar.gz}
echo "Creating extra package '${EXTRAPACKAGE}' with the remaining files"
${TAR_COMMAND} "${EXTRAPACKAGE}" \
    --exclude=./public/hot \
    --exclude=./public/storage \
    --exclude=./storage \
    --exclude=./artifacts \
    --exclude-from="$tmpfile" .  || error_exit "Creating extra archive failed"

rm "$tmpfile"

cd artifacts
md5sum * > MD5SUMS