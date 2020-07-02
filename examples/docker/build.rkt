#lang racket/base
(require pkg-build
         racket/runtime-path)

;; Don't run as a test:
(module test racket/base)

(define-runtime-path workdir "workdir")

(module+ main
  (build-pkgs
   #:work-dir workdir
   #:snapshot-url "https://mirror.racket-lang.org/releases/7.6/"

   #:installer-platform-name "{1} Racket | {3} Linux | {3} x64_64 (64-bit), natipkg; built on Debian 8 (Jessie)"

   #:pkgs-for-version "7.6"
   
   #:extra-packages '("main-distribution-test")

   #:summary-omit-pkgs bin-pkgs
   #:built-at-site? #t
   #:site-url "https://pkg-build.racket-lang.org"
   
   #:install-doc-list-file "orig-docs.txt"

   #:timeout 2400
   
   #:vms (list
          (make-docker-vms "pkg-build")
          #;
          (make-docker-vms "pkg-build2"))
   
   #:steps (steps-in 'download 'site)))

;; Create Docker "full" and "minimal" variants:
(define (make-docker-vms name)
  (docker-vm
   #:name name
   #:from-image "racket/pkg-build-deps"
   #:env test-env
   #:shell xvfb-shell
   #:minimal-variant (docker-vm #:name (string-append name "-min")
                                #:from-image "racket/pkg-build-deps-min")))

;; Some packages may depend on this, since pkg-build.racket-lang.org
;; defines it:
(define test-env
  (list (cons "PLT_PKG_BUILD_SERVICE" "1")))

;; Use `xvfb-run` on the non-minimal VM to allow GUI programs to work:
(define xvfb-shell
  '("/usr/bin/xvfb-run" "-n" "1" "/bin/sh" "-c"))

;; Omitting these cleans up the summarry:
(define bin-pkgs
  (list "com-win32-i386" "com-win32-x86_64"
        "db-ppc-macosx" "db-win32-i386" "db-win32-x86_64"
        "db-x86_64-linux-natipkg"
        "draw-i386-macosx" "draw-i386-macosx-2"
        "draw-ppc-macosx" "draw-ppc-macosx-2"
        "draw-win32-i386" "draw-win32-i386-2"
        "draw-win32-x86_64" "draw-win32-x86_64-2"
        "draw-x86_64-macosx" "draw-x86_64-macosx-2"
        "draw-x86_64-linux-natipkg-2"
        "draw-ttf-x86_64-linux-natipkg" "draw-x11-x86_64-linux-natipkg"
        "gui-i386-macosx" "gui-ppc-macosx" "gui-win32-i386"
        "gui-win32-x86_64" "gui-x86_64-macosx"
        "gui-x86_64-linux-natipkg"
        "math-i386-macosx" "math-ppc-macosx" "math-win32-i386"
        "math-win32-x86_64" "math-x86_64-macosx"
        "math-x86_64-linux-natipkg"
        "racket-win32-i386" "racket-win32-i386-2"
        "racket-win32-x86_64" "racket-win32-x86_64-2"
	"racket-x86_64-macosx-2" "racket-i386-macosx-2"
	"racket-ppc-macosx-2"
        "racket-x86_64-linux-natipkg-2"))

