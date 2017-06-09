#!/bin/bash

VERSION=$1
IMAGE=spip
TARGET=ipeos/$IMAGE:$VERSION

if [[ -z "$VERSION" ]]; then
  echo "Usage: $0 <version>"
  exit 1
fi

if [ $VERSION = "latest" ]; then
  docker build -t $TARGET 3.1
  exit 1;
fi

docker build -t $TARGET $VERSION
exit 1;
