#lang racket/base
(require racket/format
         racket/date
         racket/contract
         remote-shell/ssh
         remote-shell/vbox
         remote-shell/docker
         "config.rkt"
         "status.rkt")

(provide (struct-out vm)
         (struct-out vm-vbox)
         (struct-out vm-docker)

         check-distinct-vm-names
         any-vbox-vms?

         (contract-out
          [vbox-vm (->* (#:name string? #:host string?)
                        (#:user string?
                         #:ssh-key (or/c #f path-string?)
                         #:dir (and/c string? complete-as-unix-path?)
                         #:env (listof (cons/c string? string?))
                         #:shell (listof string?)
                         #:init-shapshot string?
                         #:installed-shapshot string?
                         #:minimal-variant (or/c #f vm?)
                         #:fallback-variant (or/c #f vm?)
                         #:test-timeout [or/c #f exact-nonnegative-integer?])
                        vm?)]
          [docker-vm (->* (#:name string? #:from-image string?)
                          (#:dir (and/c string? complete-as-unix-path?)
                           #:env (listof (cons/c string? string?))
                           #:shell (listof string?)
                           #:minimal-variant (or/c #f vm?)
                           #:fallback-variant (or/c #f vm?)
                           #:test-timeout [or/c #f exact-nonnegative-integer?]
                           #:memory-mb (or/c #f exact-nonnegative-integer?)
                           #:swap-mb (or/c #f exact-nonnegative-integer?)
                           #:platform (or/c #f string?))
                          vm?)])
         q
         cd-racket
         mcr
         make-sure-vm-is-ready

         vm-config-key
         vm-remote
         vm-reset
         vm-start
         vm-stop)

(struct vm (name host user dir env shell minimal-variant fallback-variant timeout))
(struct vm-vbox vm (init-snapshot installed-snapshot ssh-key))
(struct vm-docker vm (from-image memory-mb swap-mb platform))

(define (complete-as-unix-path? dir)
  (complete-path? (bytes->path (string->bytes/utf-8 dir) 'unix)))
(module+ test
  (require rackunit)
  (check-true (complete-as-unix-path? "/Users/home/name"))
  (check-false (complete-as-unix-path? "home/name"))
  (check-false (complete-as-unix-path? "C:\\a\\b\\c")))

;; Each VM must provide at least an ssh server and `tar`, and the
;; intent is that it is otherwise isolated (e.g., no network
;; connection except to the host)
(define (vbox-vm
         ;; VirtualBox VM name:
         #:name name
         ;; IP address of VM (from host):
         #:host host
         ;; User for ssh login to VM:
         #:user [user "racket"]
         ;; Working directory on VM:
         #:dir [dir "/home/racket/build-pkgs"]
         ;; Environment variables as (list (cons <str> <str>) ...)
         #:env [env null]
         ;; Command to run a single-stringa shell command
         #:shell [shell '("/bin/sh" "-c")]
         ;; Name of a clean starting snapshot in the VM:
         #:init-shapshot [init-snapshot "init"]
         ;; An "installed" snapshot is created after installing Racket
         ;; and before building any package:
         #:installed-shapshot [installed-snapshot "installed"]
         ;; If not #f, a `vm` that is more constrained and will be
         ;; tried as an installation target before this one, and this
         ;; one will be used only of the minimal variant fails;
         ;; *does not* recur to nested minimal and fallback variants:
         #:minimal-variant [minimal-variant #f]
         ;; If not #f, a `vm` (perhaps for a different architecture) that
         ;; will be tried if this one fails (with no recur):
         #:fallback-variant [fallback-variant #f]
         ;; used with `raco test`, timeout in seconds
         #:test-timeout [test-timeout #f]
         ;; Limit on "real" memory available to the container in megabytes:
         ;; Path to ssh key to use to connect to this VM:
         ;; #f indicates that ssh's defaults are used
         #:ssh-key [ssh-key #f])
  (vm-vbox name host user dir env shell minimal-variant fallback-variant test-timeout
           init-snapshot installed-snapshot ssh-key))

;; Suggsted base Docker image names, available from Docker Hub:
;;
;;   racket/pkg-build:deps             - for linux/amd64 and linux/arm64/v8
;;   racket/pkg-build:deps-min         - for linux/amd64 and linux/arm64/v8
;;   racket/pkg-build:deps-x86_64      - for linux/amd64 only
;;   racket/pkg-build:deps-min-x86_64  - for linux/amd64 only
;;   racket/pkg-build:deps-aarch64     - for linux/arm64/v8 only
;;   racket/pkg-build:deps-min-aarch64 - for linux/arm64/v8 only

(define (docker-vm
         ;; Docker image label:
         #:name name
         ;; Base image (see suggetsed list above):
         #:from-image from-image
         ;; Working directory in image:
         #:dir [dir "/home/root/"]
         ;; Environment variables as (list (cons <str> <str>) ...)
         #:env [env null]
         ;; Command to run a single-stringa shell command
         #:shell [shell '("/bin/sh" "-c")]
         ;; If not #f, a `vm` that is more constrained and will be
         ;; tried as an installation target before this one, and this
         ;; one will be used only of the minimal variant fails;
         ;; *does not* recur to nested minimal and fallback variants:
         #:minimal-variant [minimal-variant #f]
         ;; If not #f, a `vm` (perhaps for a different architecture) that
         ;; will be tried if this one fails (with no recur):
         #:fallback-variant [fallback-variant #f]
         ;; used with `raco test`, timeout in seconds
         #:test-timeout [test-timeout #f]
         ;; Limit on "real" memory available to the container in megabytes:
         #:memory-mb [memory-mb  #f]
         ;; Amount of additional swap space available, defaults to `memory-mb`:
         #:swap-mb [swap-mb #f]
         ;; Optional platform, which normally should be `linux/amd64" or "linux/arm64/v8";
         ;; needs to be specified if it doesn't match the host (i.e., emulation
         ;; is available at the Docker level); beware that different platforms cannot
         ;; use the same image name, so for multiple platforms, used images like 
         ;; "racket/pkg-build:deps-x86_64" and "racket/pkg-build:deps-aarch_64" instead
         ;; of the tags without an architecture
         #:platform [platform #f])
  (vm-docker name name "" dir env shell minimal-variant fallback-variant test-timeout
             from-image
             memory-mb swap-mb
             platform))

(define (check-distinct-vm-names vms)
  (let loop ([names #hash()] [vms vms])
    (cond
      [(null? vms) names]
      [else
       (define vm (car vms))
       (when (hash-ref names (vm-name vm) #f)
         (error 'build-pkgs "duplicate VM name ~s" (vm-name vm)))
       (loop (hash-set names (vm-name vm) #t)
             (if (vm-minimal-variant vm)
                 (cons (vm-minimal-variant vm)
                       (cdr vms))
                 (cdr vms)))])))

(define (any-vbox-vms? vms)
  (let loop ([vms vms])
    (cond
      [(null? vms) #f]
      [else
       (define vm (car vms))
       (or (vm-vbox? vm)
           (vm-vbox? (vm-minimal-variant vm))
           (loop (cdr vms)))])))

;; ----------------------------------------
 
(define (q s)
  (~a "\"" s "\""))

(define (cd-racket vm) (~a "cd " (q (vm-dir vm)) "/racket"))

(define (mcr vm machine-independent?)
  (if machine-independent?
      (~a " -MCR " (q (vm-dir vm)) "/zo:")
      ""))

(define (make-sure-vm-is-ready vm rt)
  (when (vm-vbox? vm)
    (make-sure-remote-is-ready rt)
    (status "Fixing time at ~a\n" (vm-name vm))
    (ssh rt "sudo date --set=" (q (parameterize ([date-display-format 'rfc2822])
                                    (date->string (seconds->date (current-seconds)) #t))))))

;; ----------------------------------------

;; Used to detect changes that trigger rebuilding the installed state:
(define (vm-config-key vm)
  (cond
    [(vm-vbox? vm)
     (vm-vbox-installed-snapshot vm)]
    [(vm-docker? vm) null]))

(define (vm-remote vm config machine-independent?)
  (remote #:host (vm-host vm)
          #:kind (if (vm-docker? vm)
                     'docker
                     'ip)
          #:user (vm-user vm)
          #:env (append
                 (list (cons "PLTUSERHOME"
                             (~a (vm-dir vm) "/user"))
                       (cons "PLT_PKG_BUILD_SERVICE" "1")
                       (cons "CI" "true")
                       (cons "PLT_INFO_ALLOW_VARS"
                             (string-append
                              (let ([a (assoc "PLT_INFO_ALLOW_VARS" (vm-env vm))])
                                (if a (cdr a) ""))
                              ";PLT_PKG_BUILD_SERVICE")))
                 (if machine-independent?
                     (list
                      (cons "PLTCOMPILEDROOTS" (string-append (vm-dir vm) "/zo:")))
                     null)
                 (vm-env vm))
          #:shell (vm-shell vm)
          #:key (and (vm-vbox? vm)
                     (vm-vbox-ssh-key vm))
          #:timeout (config-timeout config)
          #:remote-tunnels (if (vm-docker? vm)
                               null
                               (list (cons (config-server-port config)
                                           (config-server-port config))))))

(define (vm-reset vm config)
  (cond
    [(vm-vbox? vm)
     (restore-vbox-snapshot (vm-name vm) (vm-vbox-installed-snapshot vm))]
    [(vm-docker? vm)
     (docker-create #:name (vm-name vm)
                    #:image-name (vm-name vm)
                    #:platform (vm-docker-platform vm)
                    #:volumes (list
                               (list (config-server-dir config)
                                     (format "~a/catalogs" (vm-dir vm))
                                     'ro))
                    #:network "none"
                    #:memory-mb (vm-docker-memory-mb vm)
                    #:swap-mb (vm-docker-swap-mb vm)
                    #:replace? #t)]))

(define (vm-start vm #:max-vms max-vms)
  (cond
    [(vm-vbox? vm)
     (start-vbox-vm (vm-name vm) #:max-vms max-vms)]
    [(vm-docker? vm)
     (docker-start #:name (vm-name vm))]))

(define (vm-stop vm)
  (cond
    [(vm-vbox? vm)
     (stop-vbox-vm (vm-name vm) #:save-state? #f)]
    [(vm-docker? vm)
     (when (docker-running? #:name (vm-name vm))
       (docker-stop #:name (vm-name vm)))]))
