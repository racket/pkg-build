#lang info
(define collection "pkg-build")
(define deps '(["base" #:version "7.7.0.1"]
               "rackunit"
               "scribble-html-lib"
               "web-server-lib"
               "plt-web-lib"
               ["remote-shell-lib" #:version "1.3"]))
(define build-deps '("at-exp-lib"
                     "scribble-lib"
                     "racket-doc"))

(define scribblings '(("pkg-build.scrbl" (multi-page))))
