#lang racket

(require "../../../framework/core-stage-q.rkt"
         (prefix-in source: "../source/vertical.rkt")
         (prefix-in s: "./s.rkt")
         (prefix-in e: "./e.rkt")
         (prefix-in n: "./n.rkt"))

(provide
 (rename-out [source:Q-SE/generated Q-SE/R/stages]
             [source:Q-EN/generated Q-EN/R/stages]
             [source:Q-SN/generated Q-SN/R/stages]
             [source:Q-SN-composition/generated?
              Q-SN/R-composition/stages?])
 Q-SE/C/stages
 Q-SE/D/stages
 Q-SE/D/transport/stages
 Q-SE/Z/stages
 Q-SE/Z/transport/stages
 Q-SE/M/stages
 Q-SE/M/transport/stages
 Q-SE/B/stages
 Q-SE/B/transport/stages
 Q-SE/Big/stages
 Q-EN/C/stages
 Q-EN/D/stages
 Q-EN/D/transport/stages
 Q-EN/Z/stages
 Q-EN/Z/transport/stages
 Q-EN/M/stages
 Q-EN/M/transport/stages
 Q-EN/B/stages
 Q-EN/B/transport/stages
 Q-EN/Big/stages
 Q-SN/C/stages
 Q-SN/D/stages
 Q-SN/D/transport/stages
 Q-SN/Z/stages
 Q-SN/Z/transport/stages
 Q-SN/M/stages
 Q-SN/M/transport/stages
 Q-SN/B/stages
 Q-SN/B/transport/stages
 Q-SN/Big/stages
 Q-SN/C-composition/stages?
 Q-SN/D-composition/stages?
 Q-SN/Z-composition/stages?
 Q-SN/M-composition/stages?
 Q-SN/B-composition/stages?
 Q-SN/Big-composition/stages?)

;; Each invocation emits direct structural maps.  The `/transport` functions
;; are deliberately separate comparators built from the public stage codecs;
;; the direct maps never call those codecs or decompose a readback.
(define-core-stage-Q-maps
  #:Q-R source:Q-SE/generated
  #:Q-focus source:Q-SE/focus/generated
  #:Q-C Q-SE/C/stages
  #:Q-D Q-SE/D/stages
  #:Q-D/transport Q-SE/D/transport/stages
  #:Q-Z Q-SE/Z/stages
  #:Q-Z/transport Q-SE/Z/transport/stages
  #:Q-M Q-SE/M/stages
  #:Q-M/transport Q-SE/M/transport/stages
  #:Q-B Q-SE/B/stages
  #:Q-B/transport Q-SE/B/transport/stages
  #:Q-Big Q-SE/Big/stages
  #:source-plug-D s:generated-stage-plug-D/s
  #:target-decompose e:generated-stage-decompose/e
  #:source-Z->D s:generated-stage-Z->D/s
  #:target-D->Z e:generated-stage-D->Z/e
  #:source-decode-MZ s:generated-stage-decode-MZ/s
  #:target-encode-ZM e:generated-stage-encode-ZM/e
  #:source-decode-BM s:generated-stage-decode-BM/s
  #:target-encode-MB e:generated-stage-encode-MB/e)

(define-core-stage-Q-maps
  #:Q-R source:Q-EN/generated
  #:Q-focus source:Q-EN/focus/generated
  #:Q-C Q-EN/C/stages
  #:Q-D Q-EN/D/stages
  #:Q-D/transport Q-EN/D/transport/stages
  #:Q-Z Q-EN/Z/stages
  #:Q-Z/transport Q-EN/Z/transport/stages
  #:Q-M Q-EN/M/stages
  #:Q-M/transport Q-EN/M/transport/stages
  #:Q-B Q-EN/B/stages
  #:Q-B/transport Q-EN/B/transport/stages
  #:Q-Big Q-EN/Big/stages
  #:source-plug-D e:generated-stage-plug-D/e
  #:target-decompose n:generated-stage-decompose/n
  #:source-Z->D e:generated-stage-Z->D/e
  #:target-D->Z n:generated-stage-D->Z/n
  #:source-decode-MZ e:generated-stage-decode-MZ/e
  #:target-encode-ZM n:generated-stage-encode-ZM/n
  #:source-decode-BM e:generated-stage-decode-BM/e
  #:target-encode-MB n:generated-stage-encode-MB/n)

(define-core-stage-Q-maps
  #:Q-R source:Q-SN/generated
  #:Q-focus source:Q-SN/focus/generated
  #:Q-C Q-SN/C/stages
  #:Q-D Q-SN/D/stages
  #:Q-D/transport Q-SN/D/transport/stages
  #:Q-Z Q-SN/Z/stages
  #:Q-Z/transport Q-SN/Z/transport/stages
  #:Q-M Q-SN/M/stages
  #:Q-M/transport Q-SN/M/transport/stages
  #:Q-B Q-SN/B/stages
  #:Q-B/transport Q-SN/B/transport/stages
  #:Q-Big Q-SN/Big/stages
  #:source-plug-D s:generated-stage-plug-D/s
  #:target-decompose n:generated-stage-decompose/n
  #:source-Z->D s:generated-stage-Z->D/s
  #:target-D->Z n:generated-stage-D->Z/n
  #:source-decode-MZ s:generated-stage-decode-MZ/s
  #:target-encode-ZM n:generated-stage-encode-ZM/n
  #:source-decode-BM s:generated-stage-decode-BM/s
  #:target-encode-MB n:generated-stage-encode-MB/n)

(define (Q-SN/C-composition/stages? contractum)
  (equal? (Q-SN/C/stages contractum)
          (Q-EN/C/stages (Q-SE/C/stages contractum))))

(define (Q-SN/D-composition/stages? decomposition)
  (equal? (Q-SN/D/stages decomposition)
          (Q-EN/D/stages (Q-SE/D/stages decomposition))))

(define (Q-SN/Z-composition/stages? refocused)
  (equal? (Q-SN/Z/stages refocused)
          (Q-EN/Z/stages (Q-SE/Z/stages refocused))))

(define (Q-SN/M-composition/stages? machine)
  (equal? (Q-SN/M/stages machine)
          (Q-EN/M/stages (Q-SE/M/stages machine))))

(define (Q-SN/B-composition/stages? compressed)
  (equal? (Q-SN/B/stages compressed)
          (Q-EN/B/stages (Q-SE/B/stages compressed))))

(define (Q-SN/Big-composition/stages? big)
  (equal? (Q-SN/Big/stages big)
          (Q-EN/Big/stages (Q-SE/Big/stages big))))
