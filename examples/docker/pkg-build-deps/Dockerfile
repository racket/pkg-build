FROM racket/pkg-build:pkg-build-deps-min
RUN apt-get update -y
RUN apt-get install gcc xvfb xterm libglib2.0-0 libpangocairo-1.0-0 -y
RUN apt-get install libjpeg8 libpng12-0 libgtk2.0-0 libgdk-pixbuf2.0-0 libunique-1.0-0 -y
ENTRYPOINT ["/bin/bash"]
