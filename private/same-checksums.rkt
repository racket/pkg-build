#lang racket/base
(require racket/file
         pkg/lib
         (prefix-in db: pkg/db))

(provide check-same-checksums)

(define (check-same-checksums snapshot-catalog
                              archive-catalog
                              pkgs-for-version)
  (define temp-snapshot-db (make-temporary-file "snapshot-pkg~a.sqlite"))
  (define temp-archive-db (make-temporary-file "archive-pkg~a.sqlite"))
  (delete-file temp-snapshot-db)
  (delete-file temp-archive-db)

  (parameterize ([current-pkg-lookup-version pkgs-for-version])
    (pkg-catalog-copy (list snapshot-catalog)
                      temp-snapshot-db))
  (parameterize ([current-pkg-lookup-version pkgs-for-version])
    (pkg-catalog-copy (list archive-catalog)
                      temp-archive-db))

  (define snapshot-pkgs
    (parameterize ([db:current-pkg-catalog-file temp-snapshot-db])
      (db:get-pkgs)))
  (define archive-pkgs
    (parameterize ([db:current-pkg-catalog-file temp-archive-db])
      (db:get-pkgs)))

  (delete-file temp-snapshot-db)
  (delete-file temp-archive-db)

  (let ([ht (for/hash ([pkg (in-list snapshot-pkgs)])
              (values (db:pkg-name pkg) pkg))])
    (for ([pkg (in-list archive-pkgs)])
      (define snapshot-pkg (hash-ref ht (db:pkg-name pkg) #f))
      (when snapshot-pkg
        (unless (equal? (db:pkg-checksum pkg) (db:pkg-checksum snapshot-pkg))
          (error (string-append
                  "archived package checksum does not match snapshot's catalog;\n"
                  " this mismatch would means that updating packages in a build\n"
                  " installation would try to replace the installation's existing\n"
                  " packages installs with archived versions, which is bad and slow\n"
                  "  package: " (db:pkg-name pkg) "\n"
                  "  snapshot checksum: " (db:pkg-checksum snapshot-pkg) "\n"
                  "  archive checksum: " (db:pkg-checksum pkg))))))))
