#lang racket/base
(require racket/format
         racket/runtime-path
         racket/file
         file/untgz
         remote-shell/vbox
         remote-shell/docker
         remote-shell/ssh
         pkg/lib
         net/url
         "config.rkt"
         "vm.rkt"
         "status.rkt")

(provide install-step)

(define-runtime-path pkg-list-rkt "pkg-list.rkt")
(define-runtime-path pkg-adds-rkt "pkg-adds.rkt")

(define (install-step vms
                      config
                      installer-dir
                      installer-name
                      archive-dir
                      extra-packages
                      work-dir
                      install-doc-list-file)
  
  (define (do-install ssh scp-to rt vm
                      #:filesystem-catalog? [filesystem-catalog? #t]
                      #:pre-pkg-install [pre-pkg-install void])
    (define there-dir (vm-dir vm))
    (status "Preparing directory ~a\n" there-dir)
    (ssh rt "rm -rf " (~a (q there-dir) "/*"))
    (ssh rt "mkdir -p " (q there-dir))
    (ssh rt "mkdir -p " (q (~a there-dir "/user")))
    (ssh rt "mkdir -p " (q (~a there-dir "/built")))
    
    (scp-to rt (build-path installer-dir installer-name) there-dir)
    
    (ssh rt "cd " (q there-dir) " && " " sh " (q installer-name) " --in-place --dest ./racket")
    
    ;; VM-side helper modules:
    (scp-to rt pkg-adds-rkt (~a there-dir "/pkg-adds.rkt"))
    (scp-to rt pkg-list-rkt (~a there-dir "/pkg-list.rkt"))

    (status "Setting catalogs at ~a\n" (vm-name vm))
    (ssh rt (cd-racket vm)
         " && bin/raco pkg config -i --set catalogs "
         (cond
           [filesystem-catalog?
            (~a " file://" (q there-dir) "/catalogs/built/catalog"
                " file://" (q there-dir) "/catalogs/archive/catalog")]
           [else
            (~a " http://localhost:" (~a (config-server-port config)) "/built/catalog/"
                " http://localhost:" (~a (config-server-port config)) "/archive/catalog/")]))

    (ssh rt (cd-racket vm)
         " && bin/raco pkg config -i --set trash-max-packages 0")

    (unless (null? extra-packages)
      (pre-pkg-install)
      (status "Extra package installs at ~a\n" (vm-name vm))
      (ssh rt (cd-racket vm)
           " && bin/raco pkg install -i --auto"
           " " (apply ~a #:separator " " extra-packages))))

  (define (extract-installed rt vm)
    (define there-dir (vm-dir vm))

    (status "Getting installed packages\n")
    (ssh rt (cd-racket vm)
         " && bin/racket ../pkg-list.rkt > ../pkg-list.rktd")
    (scp rt (at-remote rt (~a there-dir "/pkg-list.rktd"))
         (build-path work-dir "install-list.rktd"))

    (status "Stashing installation docs\n")
    (ssh rt (cd-racket vm)
         " && bin/racket ../pkg-adds.rkt --all > ../pkg-adds.rktd")
    (ssh rt (cd-racket vm)
         " && tar zcf ../install-doc.tgz doc")
    (scp rt (at-remote rt (~a there-dir "/pkg-adds.rktd"))
         (build-path work-dir "install-adds.rktd"))
    (scp rt (at-remote rt (~a there-dir "/install-doc.tgz"))
         (build-path work-dir "install-doc.tgz")))
  
  (define (install vm
                   #:extract-installed? [extract-installed? #f])
    (cond
      ;; VirtualBox mode
      [(vm-vbox? vm)
       (status "Starting VM ~a\n" (vm-name vm))
       (stop-vbox-vm (vm-name vm))
       (restore-vbox-snapshot (vm-name vm) (vm-vbox-init-snapshot vm))
       
       (dynamic-wind
        (lambda () (start-vbox-vm (vm-name vm)))
        (lambda ()
          (define rt (vm-remote vm))
          (define (scp-to rt src dest)
            (scp remote src (at-remote rt dest)))
          (make-sure-vm-is-ready vm rt)
          (do-install ssh scp-to rt vm)
          (when extract-installed?
            (extract-installed rt vm)))
        (lambda ()
          (stop-vbox-vm (vm-name vm))))

       (status "Taking installation snapshopt\n")
       (when (exists-vbox-snapshot? (vm-name vm) (vm-vbox-installed-snapshot vm))
         (delete-vbox-snapshot (vm-name vm) (vm-vbox-installed-snapshot vm)))
       (take-vbox-snapshot (vm-name vm) (vm-vbox-installed-snapshot vm))]
      ;; Docker mode
      [(vm-docker? vm)
       (status "Building VM ~a\n" (vm-name vm))
       (when (docker-image-id #:name (vm-name vm))
         (when (docker-running? #:name (vm-name vm))
           (docker-stop #:name (vm-name vm)))
         (when (docker-id #:name (vm-name vm))
           (docker-remove #:name (vm-name vm)))
         (docker-image-remove #:name (vm-name vm)))

       (define build-dir (make-temporary-file "pkg-build-~a" 'directory))

       (unless (null? extra-packages)
         (pkg-catalog-archive #:fast-file-copy? #t
                              #:relative-sources? #t
                              #:include extra-packages
                              #:include-deps? #t
                              (build-path build-dir "archive")
                              (list (url->string (path->url (build-path archive-dir "catalog"))))))

       (dynamic-wind
        void
        (lambda ()
          (call-with-output-file*
           (build-path build-dir "Dockerfile")
           (lambda (o)
             (fprintf o "FROM ~a\n" (vm-docker-from-image vm))
             (for ([p (in-list (vm-env vm))])
               (fprintf o "ENV ~a ~a\n" (car p) (cdr p)))
             (define (build-ssh rt . strs)
               (fprintf o "RUN ")
               (for ([str (in-list strs)])
                 (fprintf o "~a" str))
               (newline o))
             (define (build-scp-to rt here there)
               (define-values (base name dir?) (split-path here))
               (copy-file here (build-path build-dir name))
               (fprintf o "COPY ~a ~a\n" name there))
             (do-install build-ssh build-scp-to 'dummy-rt vm
                         #:filesystem-catalog? #t
                         #:pre-pkg-install
                         (lambda ()
                           (fprintf o "COPY archive ~a/catalogs/archive\n" (q (vm-dir vm)))))
             (unless (null? extra-packages)
               (fprintf o "RUN rm -r ~a/catalogs/archive" (q (vm-dir vm))))))
          (docker-build #:content build-dir
                        #:name (vm-name vm))
          (status "Container built as ~a\n" (docker-image-id #:name (vm-name vm))))
        (lambda ()
          (delete-directory/files build-dir)))

       (when extract-installed?
         (vm-reset vm config)
         (dynamic-wind
          (lambda ()
            (vm-start vm #:max-vms 1))
          (lambda ()
            (extract-installed (vm-remote vm config) vm))
          (lambda ()
            (vm-stop vm))))]))

  (define (check-and-install vm #:extract-installed? [extract-installed? #f])
    (define uuids (with-handlers ([exn:fail? (lambda (exn)
                                               (hash))])
                    (define ht
                      (call-with-input-file*
                       (build-path work-dir "install-uuids.rktd")
                       read))
                    (if (hash? ht)
                        ht
                        (hash))))
    (define key (list (vm-name vm) (vm-config-key vm)))
    (define uuid (hash-ref uuids key #f))
    (define (get-vm-id)
      (cond
        [(vm-vbox? vm)
         (get-vbox-snapshot-uuid (vm-name vm) (vm-vbox-installed-snapshot vm))]
        [(vm-docker? vm)
         (docker-image-id #:name (vm-name vm))]))
    (cond
      [(and uuid (equal? uuid (get-vm-id)))
       (status "VM ~a is up-to-date~a\n" (vm-name vm)
               (if (vm-vbox? vm)
                   (format " for ~a" (vm-vbox-installed-snapshot vm))
                   ""))]
      [else
       (install vm #:extract-installed? extract-installed?)
       (define uuid (get-vm-id))
       (call-with-output-file*
        (build-path work-dir "install-uuids.rktd")
        #:exists 'truncate
        (lambda (o)
          (writeln (hash-set uuids key uuid) o)))]))

  (for ([vm (in-list vms)]
        [i (in-naturals)])
    (check-and-install vm #:extract-installed? (zero? i))
    (when (vm-minimal-variant vm)
      (check-and-install (vm-minimal-variant vm))))

  (when install-doc-list-file
    (call-with-output-file*
     install-doc-list-file
     #:exists 'truncate
     (lambda (o)
       (untgz (build-path work-dir "install-doc.tgz")
              #:filter (lambda (p . _)
                         (displayln p o)
                         #f))))))
