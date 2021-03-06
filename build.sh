#! /bin/bash

IMG_NAME=cyrilix/alertmanager
VERSION=0.15.3
MAJOR_VERSION=0.15
export DOCKER_CLI_EXPERIMENTAL=enabled
export DOCKER_USERNAME=cyrilix

set -e

init_qemu() {
    local qemu_url='https://github.com/multiarch/qemu-user-static/releases/download/v2.9.1-1'

    docker run --rm --privileged multiarch/qemu-user-static:register --reset

    for target_arch in aarch64 arm x86_64; do
        wget -N "${qemu_url}/x86_64_qemu-${target_arch}-static.tar.gz";
        tar -xvf "x86_64_qemu-${target_arch}-static.tar.gz";
    done
}

fetch_sources() {
    if [[ ! -d  prometheus ]] ;
    then
        git clone https://github.com/prometheus/alertmanager.git
    fi
    cd alertmanager
    git checkout v${VERSION}

    go get github.com/prometheus/alertmanager/cmd/alertmanager
}

build_and_push_images() {
    local arch="$1"
    local dockerfile="$2"

    docker build --file "${dockerfile}" --tag "${IMG_NAME}:${arch}-latest" .
    docker tag "${IMG_NAME}:${arch}-latest" "${IMG_NAME}:${arch}-${VERSION}"
    docker tag "${IMG_NAME}:${arch}-latest" "${IMG_NAME}:${arch}-${MAJOR_VERSION}"
    docker push "${IMG_NAME}:${arch}-latest"
    docker push "${IMG_NAME}:${arch}-${VERSION}"
    docker push "${IMG_NAME}:${arch}-${MAJOR_VERSION}"
}


build_manifests() {
    docker -D manifest create "${IMG_NAME}:${VERSION}" "${IMG_NAME}:amd64-${VERSION}" "${IMG_NAME}:arm-${VERSION}"
    docker -D manifest annotate "${IMG_NAME}:${VERSION}" "${IMG_NAME}:arm-${VERSION}" --os=linux --arch=arm --variant=v6
    docker -D manifest push "${IMG_NAME}:${VERSION}"

    docker -D manifest create "${IMG_NAME}:latest" "${IMG_NAME}:amd64-latest" "${IMG_NAME}:arm-latest"
    docker -D manifest annotate "${IMG_NAME}:latest" "${IMG_NAME}:arm-latest" --os=linux --arch=arm --variant=v6
    docker -D manifest push "${IMG_NAME}:latest"

    docker -D manifest create "${IMG_NAME}:${MAJOR_VERSION}" "${IMG_NAME}:amd64-${MAJOR_VERSION}" "${IMG_NAME}:arm-${MAJOR_VERSION}"
    docker -D manifest annotate "${IMG_NAME}:${MAJOR_VERSION}" "${IMG_NAME}:arm-${MAJOR_VERSION}" --os=linux --arch=arm --variant=v6
    docker -D manifest push "${IMG_NAME}:${MAJOR_VERSION}"
}

fetch_sources
init_qemu

echo "$DOCKER_PASSWORD" | docker login -u "$DOCKER_USERNAME" --password-stdin

GOOS=linux GOARCH=amd64 make build
build_and_push_images amd64 ./Dockerfile

sed "s#FROM \+\(.*\)#FROM arm32v6/busybox\n\nCOPY qemu-arm-static /usr/bin/\n#" Dockerfile > Dockerfile.arm
GOOS=linux GOARCH=arm GOARM=6 make build
build_and_push_images arm ./Dockerfile.arm

build_manifests
