# Build and push with
#  docker buildx build --push --platform linux/arm64/v8,linux/amd64 --tag racket/pkg-build:deps .
#  # (try `docker buildx create --use desktop-linux` first if that fails)
#
#  docker pull --platform linux/amd64 racket/pkg-build:deps
#  docker image tag racket/pkg-build:deps racket/pkg-build:deps-x86_64
#  docker push racket/pkg-build:deps-x86_64
#
#  docker pull --platform linux/arm64/v8 racket/pkg-build:deps
#  docker image tag racket/pkg-build:deps racket/pkg-build:deps-aarch64
#  docker push racket/pkg-build:deps-aarch64
#
#
FROM racket/pkg-build:deps-min
RUN apt-get update -y
RUN apt-get install ca-certificates tzdata -y
RUN apt-get install gcc -y
RUN apt-get install xvfb -y
RUN apt-get install xterm -y
ENTRYPOINT ["/bin/bash"]
