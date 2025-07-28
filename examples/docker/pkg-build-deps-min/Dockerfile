# Build and push with
#  docker buildx build --push --platform linux/arm64/v8,linux/amd64 --tag racket/pkg-build:deps-min .
#  # (try `docker buildx create --use desktop-linux` first if that fails)
#
#  docker pull --platform linux/amd64 racket/pkg-build:deps-min
#  docker image tag racket/pkg-build:deps-min racket/pkg-build:deps-min-x86_64
#  docker push racket/pkg-build:deps-min-x86_64
#
#  docker pull --platform linux/arm64/v8 racket/pkg-build:deps-min
#  docker image tag racket/pkg-build:deps-min racket/pkg-build:deps-min-aarch64
#  docker push racket/pkg-build:deps-min-aarch64
#
#
FROM ubuntu:16.04
RUN apt-get update -y
RUN apt-get install ca-certificates tzdata -y
ENTRYPOINT ["/bin/bash"]
