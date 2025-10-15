#lang racket/base
(require pkg-build
         racket/runtime-path
         racket/format)

;; Don't run as a test:
(module test racket/base)

(define-runtime-path workdir "workdir")

(define fallback-arch
  (case (system-type 'arch)
    [(aarch64) 'x86_64]
    [else #f]))

(define vers "8.17")

(module+ main
  (build-pkgs
   #:work-dir workdir
   #:snapshot-url (~a "https://mirror.racket-lang.org/releases/" vers "/")

   #:installer-name (~a "racket-" vers "-" (system-type 'arch) "-linux-natipkg-pkg-build.sh")
   #:fallback-installer-name (and fallback-arch
                                  (~a "racket-" vers "-" fallback-arch "-linux-natipkg-pkg-build.sh"))

   #:compile-any? #t ; need to be consistent with the installer

   #:pkgs-for-version vers
   
   #:extra-packages '("main-distribution-test")

   #:built-at-site? #t
   #:site-url "https://pkg-build.racket-lang.org"
   
   #:install-doc-list-file "orig-docs.txt"

   #:timeout 2400
   
   #:vms (list
          (make-docker-vms "pkg-build")
          #;
          (make-docker-vms "pkg-build2"))
   
   #:steps (steps-in 'download 'site)))

;; Set to #f to disable the memory limit on containers; if not #f,
;; twice as much memory will be available counting swap:
(define memory-mb 1024)

;; Create Docker "full" and "minimal" variants:
(define (make-docker-vms name)
  (docker-vm
   #:name name
   #:from-image (~a "racket/pkg-build:deps-" (system-type 'arch))
   #:shell xvfb-shell
   #:memory-mb memory-mb
   #:minimal-variant (docker-vm #:name (string-append name "-min")
                                #:from-image (~a "racket/pkg-build:deps-min-" (system-type 'arch))
                                #:memory-mb memory-mb)
   #:fallback-variant (and fallback-arch
                           (docker-vm #:name (string-append name "-fallback")
                                      #:from-image (~a "racket/pkg-build:deps-" fallback-arch)
                                      #:platform (case fallback-arch
                                                   [(x86_64) "linux/amd64"]
                                                   [else "unknown fallabck platform"])
                                      #:shell xvfb-shell
                                      #:memory-mb memory-mb))))

;; Use `xvfb-run` on the non-minimal VM to allow GUI programs to work:
(define xvfb-shell
  '("/usr/bin/xvfb-run" "--auto-servernum" "/bin/sh" "-c"))
