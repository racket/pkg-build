#lang info
(define collection "pkg-build")
(define deps '("base" "rackunit" "scribble-html-lib" "web-server-lib"
               "plt-web-lib" ("remote-shell-lib" #:version "1.1")))
(define build-deps '("at-exp-lib"))
