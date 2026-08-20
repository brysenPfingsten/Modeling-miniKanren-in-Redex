#lang racket

(require "sexpr-read.rkt")

(provide check-syntax-capture-error)

;; String -> String or Error
;; Purpose: Uses syntax-spec to throw static errors in the given program.
(define (check-syntax-capture-error program-str)
  (parameterize ([current-namespace (make-base-namespace)])
    (expand (datum->syntax #f
                           `(module syntax-checker racket/base
                              (require hosted-minikanren)
                              ,@(read-all-sexprs (open-input-string program-str)))))))
