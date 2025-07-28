#lang at-exp racket/base
(require racket/format
         racket/file
         scribble/html
         (only-in plt-web site page call-with-registered-roots)
         "about.rkt")

(provide summary-page
         (struct-out doc/main)
         (struct-out doc/extract)
         (struct-out doc/salvage)
         (struct-out doc/none)
         (struct-out conflicts/indirect))

(struct doc/main (name path) #:prefab)
(struct doc/extract (name path) #:prefab)
(struct doc/salvage (name path) #:prefab)
(struct doc/none (name) #:prefab)

(struct conflicts/indirect (path) #:prefab)

(define (summary-page summary-ht dest-dir
                      #:pkg-catalogs [pkg-catalogs (list "https://pkgs.racket-lang.org/")]
                      #:built-at-site? [built-at-site? #f]
                      #:site-url [site-url #f]
                      #:site-starting-point [site-starting-point #f])
  (define site-name "pkg-build")
  (define page-site (site site-name
                          #:url (or site-url "https://pkg-build.racket-lang.org/")
                          #:always-abs-url? #f
                          #:share-from (site "www"
                                             #:url "https://racket-lang.org/"
                                             #:generate? #f)
                          #:navigation (list
                                        (lambda () (force about-page)))))
  (define about-site (site site-name
                           #:share-from page-site
                           #:always-abs-url? #f
                           #:meta? #f))
  (define about-page (delay (make-about about-site
                                        #:pkg-catalogs pkg-catalogs
                                        #:site-starting-point site-starting-point
                                        #:built-at-site? built-at-site?
                                        #:site-url site-url)))

  (define page-title "Package Build Results")

  (define summary
    (for/list ([pkg (in-list (sort (hash-keys summary-ht) string<?))])
      (define ht (hash-ref summary-ht pkg))
      (define failed? (and (hash-ref ht 'failure-log) #t))
      (define succeeded? (and (hash-ref ht 'success-log) #t))
      (define status
        (cond
         [(and failed? (not succeeded?)) 'failure]
         [(and succeeded? (not failed?)) 'success]
         [(and succeeded? failed?) 'confusion]
         [else 'unknown]))
      (define (more-status key [success-key #f])
        (if (eq? status 'success)
            (if (hash-ref ht key)
                'failure
                (if (or (not success-key)
                        (hash-ref ht success-key))
                    'success
                    'unknown))
            'unknown))
      (define dep-status (more-status 'dep-failure-log))
      (define test-status (more-status 'test-failure-log 'test-success-log))
      (define min-status (more-status 'min-failure-log))
      (define arch-status (more-status 'arch-failure-log))
      (define docs (hash-ref ht 'docs))
      (define author (hash-ref ht 'author))
      (define conflicts-log (hash-ref ht 'conflicts-log))
      (tr (td pkg
              (div class: "author" author))
          (td (if (null? docs)
                  ""
                  (list
                   "Docs: "
                   (add-between
                    (for/list ([doc (in-list docs)])
                      (cond
                       [(doc/main? doc)
                        (a href: (doc/main-path doc)
                           (doc/main-name doc))]
                       [(doc/extract? doc)
                        (a href: (doc/extract-path doc)
                           (doc/extract-name doc))]
                       [(doc/salvage? doc)
                        (list (a href: (doc/salvage-path doc)
                                 (doc/salvage-name doc))
                              (span class: "annotation"
                                    nbsp
                                    "(salvaged)"))]
                       [(doc/none? doc)
                        (doc/none-name doc)]
                       [else "???"]))
                    ", "))))
          (td class: (case status
                       [(failure confusion) "stop"]
                       [(success)
                        (cond
                         [(eq? dep-status 'failure)
                          "brake"]
                         [(eq? test-status 'failure)
                          "yield"]
                         [(or (eq? min-status 'failure)
                              (eq? arch-status 'failure))
                          "ok"]
                         [else "go"])]
                       [else "unknown"])
              (case status
                [(failure)
                 (a href: (hash-ref ht 'failure-log)
                    "install fails")]
                [(success)
                 (define results
                   (append
                    (list
                     (a href: (hash-ref ht 'success-log)
                        "install succeeds"))
                    (case dep-status
                      [(failure)
                       (list
                        (a href: (hash-ref ht 'dep-failure-log)
                           "dependency problems"))]
                      [else null])
                    (case test-status
                      [(failure)
                       (list
                        (a href: (hash-ref ht 'test-failure-log)
                           "test failures"))]
                      [(success)
                       (list
                        (a href: (hash-ref ht 'test-success-log)
                           "no test failures"))]
                      [else null])
                    (case arch-status
                      [(failure)
                       (list
                        (a href: (hash-ref ht 'arch-failure-log)
                           "architecture dependency"))]
                      [else null])
                    (case min-status
                      [(failure)
                       (list
                        (a href: (hash-ref ht 'min-failure-log)
                           "extra system dependencies"))]
                      [else null])))
                 (if (= 1 (length results))
                     results
                     (list* (car results)
                            " with "
                            (add-between
                             (cdr results)
                             " and with ")))]
                [(confusion)
                 (list
                  "install both "
                  (a href: (hash-ref ht 'success-log)
                     "succeeds")
                  " and "
                  (a href: (hash-ref ht 'failure-log) "fails"))]
                [else ""]))
          (td class: (if conflicts-log "stop" "neutral")
              (if conflicts-log
                  (a href: (if (conflicts/indirect? conflicts-log)
                               (conflicts/indirect-path conflicts-log)
                               conflicts-log)
                     (if (conflicts/indirect? conflicts-log)
                         "conflicts in dependency"
                         "conflicts"))
                  "")))))

  (define page-headers
    (style/inline @~a|{
                    .go { background-color: #ccffcc }
                    .ok { background-color: #ccffff }
                    .yield { background-color: #ffffcc }
                    .brake { background-color: #ffeecc }
                    .stop { background-color: #ffcccc }
                    .author { font-size: small; font-weight: normal; }
                    .annotation { font-size: small }
                  }|))

  (void (page #:site page-site
              #:file "index.html"
              #:title page-title
              (html (head (title page-title)
                          page-headers)
                    (body (table summary)))))

  ;; Render to "pkg-build", then move up:
  (call-with-registered-roots
   (lambda ()
     (parameterize ([current-directory dest-dir])
       (render-all))))

  (define sub-dir (build-path dest-dir "pkg-build"))
  (for ([f (in-list (directory-list sub-dir))])
    (define dest-f (build-path dest-dir f))
    (delete-directory/files dest-f #:must-exist? #f)
    (rename-file-or-directory (build-path sub-dir f) dest-f))
  (delete-directory sub-dir))
