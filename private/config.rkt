#lang racket/base

(provide (struct-out config))

(struct config (timeout
                server-port
                server-dir)
  #:constructor-name make-config)
