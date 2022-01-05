#!/bin/sh

set -eux

if [ -z "${CMD_PATH+x}" ]; then
  echo "::warning file=entrypoint.sh,line=6,col=1::CMD_PATH not set"
  export CMD_PATH=""
fi

PROJECT_ROOT="/go/src/github.com/${GITHUB_REPOSITORY}"
PROJECT_NAME=$(basename $GITHUB_REPOSITORY)
NAME="${NAME:-${PROJECT_NAME}_${RELEASE_NAME}}_${GOOS}_${GOARCH}"

mkdir -p $PROJECT_ROOT
rmdir $PROJECT_ROOT
ln -s $GITHUB_WORKSPACE $PROJECT_ROOT
cd $PROJECT_ROOT
go get -v ./...

EXT=''

if [ $GOOS == 'windows' ]; then
EXT='.exe'
fi

if [ -x "./build.sh" ]; then
  FILE_LIST=`./build.sh "${CMD_PATH}"`
else
  go build "${CMD_PATH}"
  FILE_LIST="${PROJECT_NAME}${EXT}"
fi

if [ -z "${EXTRA_FILES+x}" ]; then
echo "::warning file=entrypoint.sh,line=22,col=1::EXTRA_FILES not set"
fi

FILE_LIST="${FILE_LIST} ${EXTRA_FILES}"

FILE_LIST=`echo "${FILE_LIST}" | awk '{$1=$1};1'`

echo Enviroment
echo Upload URL: $UPLOAD_URL
echo Version: $RELEASE_NAME
echo Name: $NAME
echo Project root: $PROJECT_ROOT
echo Project name: $PROJECT_NAME

ARCHIVE_EXT=".tar.gz"
MEDIA_TYPE='application/gzip'
if [ $GOOS == 'windows' ]; then
ARCHIVE_EXT=".zip"
MEDIA_TYPE='application/zip'
zip -9r ${NAME}${ARCHIVE_EXT} ${FILE_LIST}
else
tar cvfz ${NAME}${ARCHIVE_EXT} ${FILE_LIST}
fi

CHECKSUM=$(md5sum ${NAME}${ARCHIVE_EXT} | cut -d ' ' -f 1)

curl \
  -X POST \
  --data-binary @${NAME}${ARCHIVE_EXT} \
  -H 'Content-Type: application/octet-stream' \
  -H "Authorization: Bearer ${GITHUB_TOKEN}" \
  "${UPLOAD_URL}?name=${NAME}.${ARCHIVE/tmp./}"

curl \
  -X POST \
  --data $CHECKSUM \
  -H 'Content-Type: text/plain' \
  -H "Authorization: Bearer ${GITHUB_TOKEN}" \
  "${UPLOAD_URL}?name=${NAME}_checksum.txt"