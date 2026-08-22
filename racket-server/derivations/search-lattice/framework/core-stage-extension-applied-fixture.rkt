#lang racket

(require "./core-stage-extension-base-fixture.rkt"
         "./core-stage-extension-query-fixture.rkt"
         "./core-stage-schema.rkt")

;; Apply the foreign feature only after every base coordinate has already been
;; generated.  The extension declaration owns the names that it provides.
(apply-selected-stage-extension
  #:extension selected-foreign/query-extension
  #:D selected-foreign/base-D
  #:Z selected-foreign/base-Z
  #:M selected-foreign/base-M
  #:B selected-foreign/base-B
  #:Big selected-foreign/base-Big)
