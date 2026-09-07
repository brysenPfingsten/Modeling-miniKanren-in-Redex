#lang racket/base

;; Selected retained-scope S correspondence and aligned native S/E/N matrix,
;; including full relation programs. The policy witness records the older
;; online source's different work order.
(require (submod "constructor-tests.rkt" test)
         "retained-scope/all.rkt"
         "matrix/all.rkt"
         (submod "policy-tests.rkt" test)
         (submod "layout-tests.rkt" test))
