#!/bin/bash
set -e

docker run --rm --privileged \
  multiarch/qemu-user-static \
  --reset -p yes

# Build for AMD64
docker build . -f Dockerfile.static -t crycco-builder
docker run -ti --rm -v "$PWD":/app --user="$UID" crycco-builder /bin/sh -c "cd /app && rm -rf lib shard.lock && shards build --release --static"
mv bin/crycco bin/crycco-static-linux-amd64

# Build for ARM64
docker build . -f Dockerfile.static --platform linux/arm64 -t crycco-builder
docker run -ti --rm -v "$PWD":/app --platform linux/arm64 --user="$UID" crycco-builder /bin/sh -c "cd /app && rm -rf lib shard.lock && shards build --release --static"
mv bin/crycco bin/crycco-static-linux-arm64
