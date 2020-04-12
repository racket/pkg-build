If you have Docker installed, then `racket build.rkt` should work.
All generated files will go in "workdir".

The "pkg-build-deps" and "pkg-build-deps-min" directories each have a
"Dockerfile" that was used to build the corresponding images that are
referenced in "build.rkt".
