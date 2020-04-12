#lang racket/base
(require net/url
         net/head
         racket/format
         racket/file
         racket/port)

(provide download-installer)

(define (download-installer snapshot-url installer-dir installer-name substatus on-download)
  (define status-file (build-path installer-dir "status.rktd"))
  (define name+etag (and (file-exists? status-file)
                         (call-with-input-file*
                          status-file
                          read)))
  (define installer-url (combine-url/relative (string->url snapshot-url)
                                              (~a "installers/" installer-name)))
  (define etag
    (cond
     [(equal? (url-scheme installer-url) "file")
      #f]
     [else
      (define-values (p h) (get-pure-port/headers installer-url
                                                  #:method #"HEAD"
                                                  #:redirections 5))
      (close-input-port p)
      (extract-field "ETag" h)]))
  (cond
   [(and (file-exists? (build-path installer-dir installer-name))
         name+etag
         (equal? (car name+etag) installer-name)
         (cadr name+etag)
         (equal? (cadr name+etag) etag))
    (substatus "Using cached installer, Etag ~a\n" etag)]
   [else
    (on-download)
    (delete-directory/files installer-dir #:must-exist? #f)
    (make-directory* installer-dir)
    (call/input-url
     installer-url
     (lambda (u [h null]) (get-pure-port u h #:redirections 5))
     (lambda (i)
       (call-with-output-file*
        (build-path installer-dir installer-name)
        #:exists 'replace
        (lambda (o)
          (copy-port i o)))))
    (when etag
      (call-with-output-file*
       status-file
       (lambda (o)
         (write (list installer-name etag) o)
         (newline o))))]))

(module+ test
  (require rackunit)
  (when (equal? (getenv "PKGBUILD_DOWNLOAD_TESTS") "x")
    (test-case "redirects get followed"
      (define output-dir (make-temporary-file "pkg-build~a" 'directory))
      (dynamic-wind
        void
        (lambda _
          (define installer-name "racket-7.4-x86_64-linux-natipkg.sh")
          (define output-filename (build-path output-dir installer-name))
          (download-installer "https://download.racket-lang.org/releases/7.4/"
                              output-dir
                              installer-name
                              void
                              void)
          (check-true (file-exists? output-filename))
          (check-true (> (file-size output-filename) 0)))
        (lambda _
          (delete-directory/files output-dir))))))
