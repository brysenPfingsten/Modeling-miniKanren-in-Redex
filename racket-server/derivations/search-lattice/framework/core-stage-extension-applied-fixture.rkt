#lang racket

(require "./core-stage-extension-base-fixture.rkt"
         "./core-stage-extension-query-fixture.rkt"
         "./core-stage-schema.rkt")

(provide selected-foreign/query-row)

;; Apply the foreign feature only after every base coordinate has already been
;; generated.  The extension declaration owns the names that it provides.
(apply-selected-stage-extension selected-foreign/query-row
  #:extension selected-foreign/query-extension
  #:base selected-foreign/base-row)
