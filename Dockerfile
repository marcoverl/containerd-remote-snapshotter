#   Copyright The containerd Authors.

#   Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
#   You may obtain a copy of the License at

#       http://www.apache.org/licenses/LICENSE-2.0

#   Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an "AS IS" BASIS,
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#   See the License for the specific language governing permissions and
#   limitations under the License.

ARG CONTAINERD_VERSION=v1.4.0-beta.1
ARG RUNC_VERSION=v1.0.0-rc90

FROM golang:1.13-buster AS golang-base

# Build containerd
FROM golang-base AS containerd-dev
ARG CONTAINERD_VERSION
RUN apt-get update -y && apt-get install -y libbtrfs-dev libseccomp-dev && \
    git clone -b ${CONTAINERD_VERSION} --depth 1 \
              https://github.com/containerd/containerd $GOPATH/src/github.com/containerd/containerd && \
    cd $GOPATH/src/github.com/containerd/containerd && \
    GO111MODULE=off make && DESTDIR=/out/ make install



# Build stargz snapshotter
FROM golang-base AS snapshotter-dev
ARG SNAPSHOTTER_BUILD_FLAGS
ARG CTR_REMOTE_BUILD_FLAGS
COPY . $GOPATH/src/github.com/marcoverl/containerd-remote-snapshotter
RUN cd $GOPATH/src/github.com/marcoverl/containerd-remote-snapshotter && \
    PREFIX=/out/ GO_BUILD_FLAGS=${SNAPSHOTTER_BUILD_FLAGS} make




# Image which can be used as a node image for KinD
FROM kindest/node:v1.27.1
COPY --from=containerd-dev /out/bin/containerd /out/bin/containerd-shim-runc-v2 /usr/local/bin/
COPY --from=snapshotter-dev /out/* /usr/local/bin/
COPY ./script/config/ /
RUN apt-get update -y && apt-get install --no-install-recommends -y fuse && \
    systemctl enable cvmfs-snapshotter
ENTRYPOINT [ "/usr/local/bin/entrypoint", "/sbin/init" ]

