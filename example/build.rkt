#lang racket/base

(require (for-syntax racket/base)
         pkg-build
         racket/runtime-path)

(define-runtime-path workdir
  (build-path "workdir"))

(build-pkgs
 #:work-dir workdir
 #:vms (list (vbox-vm #:name "pkg-build-1" #:host "192.168.33.2")
             (vbox-vm #:name "pkg-build-2" #:host "192.168.33.3"))
 #:snapshot-url "https://mirror.racket-lang.org/releases/7.5/"
 #:installer-platform-name "{1} Racket | {3} Linux | {3} x64_64 (64-bit), natipkg; built on Debian 8 (Jessie)")
