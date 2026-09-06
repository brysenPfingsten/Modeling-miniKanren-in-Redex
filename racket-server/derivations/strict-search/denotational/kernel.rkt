#lang racket

(require (only-in "../../functional-search/direct-interpreter.rkt" basic-kernel)
         "../../functional-search/outcomes.rkt")

(provide failure-outcome success-outcome basic-kernel)

;; The primitive kernel and Atom callbacks natively return functional outcomes.
;; This module only exposes that shared interface; it performs no conversion.
