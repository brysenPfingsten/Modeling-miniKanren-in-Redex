#lang racket

(require "./delay-schema.rkt"
         "./delay-schema-prefix-fixture.rkt"
         (submod "./delay-schema.rkt" test-support))

(provide delay/stage-extension/asymmetric
         asymmetric-stage-force-target-observed?)

(define-generated-delay-stage-extension delay/stage-extension/asymmetric
  #:source delay-s-asymmetric-source)

(assert-generated-delay-stage-force-target
 delay/stage-extension/asymmetric
 #:equals
 (ForcedAsymmetric (Owners) (More W)))

(define asymmetric-stage-force-target-observed? #t)
