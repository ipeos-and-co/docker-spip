#!/bin/bash

VERSION=$1
IMAGE=spip
TARGET=ipeos/$IMAGE:$VERSION

if [[ -z "$VERSION" ]]; then
  echo "Usage: $0 <version>"
  exit 1
fi

if [ $VERSION = "latest" ]; then
  sudo docker build --progress=plain -t $TARGET 4.4
  exit 1;
fi

sudo docker build --progress=plain -t $TARGET $VERSION
exit 1;
