#!/bin/bash

VERSION=$1
IMAGE=spip
TARGET=ipeos/$IMAGE:$VERSION

if [[ -z "$VERSION" ]]; then
  echo "Usage: $0 <version>"
  exit 1
fi

if [ $VERSION = "latest" ]; then
  sudo docker build -t $TARGET 4.2
  exit 1;
fi

sudo docker build -t $TARGET $VERSION
exit 1;
