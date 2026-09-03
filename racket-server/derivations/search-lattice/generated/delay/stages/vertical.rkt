#lang racket

(require "../../../framework/core-stage-schema.rkt"
         (prefix-in source: "../source/vertical.rkt")
         (prefix-in s: "s.rkt")
         (prefix-in e: "e.rkt")
         (prefix-in n: "n.rkt"))

(provide
 (rename-out [source:Q-SE/R/delay Q-SE/R/stages/delay]
             [source:Q-EN/R/delay Q-EN/R/stages/delay]
             [source:Q-SN/R/delay Q-SN/R/stages/delay]
             [source:Q-SN/R-composition/delay?
              Q-SN/R-composition/stages/delay?])
 Q-SE/D/stages/delay
 Q-SE/Z/stages/delay
 Q-SE/M/stages/delay
 Q-SE/B/stages/delay
 Q-SE/Big/stages/delay
 Q-EN/D/stages/delay
 Q-EN/Z/stages/delay
 Q-EN/M/stages/delay
 Q-EN/B/stages/delay
 Q-EN/Big/stages/delay
 Q-SN/D/stages/delay
 Q-SN/Z/stages/delay
 Q-SN/M/stages/delay
 Q-SN/B/stages/delay
 Q-SN/Big/stages/delay
 Q-SE/decompose-commutes/stages/delay?
 Q-SE/refocus-commutes/stages/delay?
 Q-SE/machineize-commutes/stages/delay?
 Q-SE/compress-commutes/stages/delay?
 Q-SE/big-commutes/stages/delay?
 Q-EN/decompose-commutes/stages/delay?
 Q-EN/refocus-commutes/stages/delay?
 Q-EN/machineize-commutes/stages/delay?
 Q-EN/compress-commutes/stages/delay?
 Q-EN/big-commutes/stages/delay?
 Q-SN/decompose-commutes/stages/delay?
 Q-SN/refocus-commutes/stages/delay?
 Q-SN/machineize-commutes/stages/delay?
 Q-SN/compress-commutes/stages/delay?
 Q-SN/big-commutes/stages/delay?
 Q-SN/D-composition/stages/delay?
 Q-SN/Z-composition/stages/delay?
 Q-SN/M-composition/stages/delay?
 Q-SN/B-composition/stages/delay?
 Q-SN/Big-composition/stages/delay?)

;; Each direct phase map consumes the two extended staged rows and the joint
;; Delay source views.  No map decodes through an earlier coordinate.
(define-decomposition-representation-map
  #:source s:delay/staged-row/S
  #:target e:delay/staged-row/E
  #:Q-R source:Q-SE/R/delay
  #:Q-focus source:Q-SE/focus/delay
  #:Q-root-focus source:Q-SE/root-focus/delay
  #:Q-terminal source:Q-SE/terminal/delay
  #:Q-D Q-SE/D/stages/delay
  #:commutes Q-SE/decompose-commutes/stages/delay?)

(define-refocused-representation-map
  #:source s:delay/staged-row/S
  #:target e:delay/staged-row/E
  #:Q-D Q-SE/D/stages/delay
  #:Q-focus source:Q-SE/focus/delay
  #:Q-root-focus source:Q-SE/root-focus/delay
  #:Q-terminal source:Q-SE/terminal/delay
  #:Q-Z Q-SE/Z/stages/delay
  #:commutes Q-SE/refocus-commutes/stages/delay?)

(define-machine-representation-map
  #:source s:delay/staged-row/S
  #:target e:delay/staged-row/E
  #:Q-Z Q-SE/Z/stages/delay
  #:Q-focus source:Q-SE/focus/delay
  #:Q-root-focus source:Q-SE/root-focus/delay
  #:Q-terminal source:Q-SE/terminal/delay
  #:Q-M Q-SE/M/stages/delay
  #:commutes Q-SE/machineize-commutes/stages/delay?)

(define-compressed-representation-map
  #:source s:delay/staged-row/S
  #:target e:delay/staged-row/E
  #:Q-M Q-SE/M/stages/delay
  #:Q-focus source:Q-SE/focus/delay
  #:Q-root-focus source:Q-SE/root-focus/delay
  #:Q-failure-focus source:Q-SE/failure-focus/delay
  #:Q-terminal source:Q-SE/terminal/delay
  #:Q-B Q-SE/B/stages/delay
  #:commutes Q-SE/compress-commutes/stages/delay?)

(define-fixed-point-representation-map
  #:source s:delay/staged-row/S
  #:target e:delay/staged-row/E
  #:Q-B Q-SE/B/stages/delay
  #:Q-terminal source:Q-SE/terminal/delay
  #:Q-Big Q-SE/Big/stages/delay
  #:commutes Q-SE/big-commutes/stages/delay?)

(define-decomposition-representation-map
  #:source e:delay/staged-row/E
  #:target n:delay/staged-row/N
  #:Q-R source:Q-EN/R/delay
  #:Q-focus source:Q-EN/focus/delay
  #:Q-root-focus source:Q-EN/root-focus/delay
  #:Q-terminal source:Q-EN/terminal/delay
  #:Q-D Q-EN/D/stages/delay
  #:commutes Q-EN/decompose-commutes/stages/delay?)

(define-refocused-representation-map
  #:source e:delay/staged-row/E
  #:target n:delay/staged-row/N
  #:Q-D Q-EN/D/stages/delay
  #:Q-focus source:Q-EN/focus/delay
  #:Q-root-focus source:Q-EN/root-focus/delay
  #:Q-terminal source:Q-EN/terminal/delay
  #:Q-Z Q-EN/Z/stages/delay
  #:commutes Q-EN/refocus-commutes/stages/delay?)

(define-machine-representation-map
  #:source e:delay/staged-row/E
  #:target n:delay/staged-row/N
  #:Q-Z Q-EN/Z/stages/delay
  #:Q-focus source:Q-EN/focus/delay
  #:Q-root-focus source:Q-EN/root-focus/delay
  #:Q-terminal source:Q-EN/terminal/delay
  #:Q-M Q-EN/M/stages/delay
  #:commutes Q-EN/machineize-commutes/stages/delay?)

(define-compressed-representation-map
  #:source e:delay/staged-row/E
  #:target n:delay/staged-row/N
  #:Q-M Q-EN/M/stages/delay
  #:Q-focus source:Q-EN/focus/delay
  #:Q-root-focus source:Q-EN/root-focus/delay
  #:Q-failure-focus source:Q-EN/failure-focus/delay
  #:Q-terminal source:Q-EN/terminal/delay
  #:Q-B Q-EN/B/stages/delay
  #:commutes Q-EN/compress-commutes/stages/delay?)

(define-fixed-point-representation-map
  #:source e:delay/staged-row/E
  #:target n:delay/staged-row/N
  #:Q-B Q-EN/B/stages/delay
  #:Q-terminal source:Q-EN/terminal/delay
  #:Q-Big Q-EN/Big/stages/delay
  #:commutes Q-EN/big-commutes/stages/delay?)

;; Direct S-to-N maps use only the S and N views/rows.  Equality with the
;; adjacent composition is a separate executable obligation below.
(define-decomposition-representation-map
  #:source s:delay/staged-row/S
  #:target n:delay/staged-row/N
  #:Q-R source:Q-SN/R/delay
  #:Q-focus source:Q-SN/focus/delay
  #:Q-root-focus source:Q-SN/root-focus/delay
  #:Q-terminal source:Q-SN/terminal/delay
  #:Q-D Q-SN/D/stages/delay
  #:commutes Q-SN/decompose-commutes/stages/delay?)

(define-refocused-representation-map
  #:source s:delay/staged-row/S
  #:target n:delay/staged-row/N
  #:Q-D Q-SN/D/stages/delay
  #:Q-focus source:Q-SN/focus/delay
  #:Q-root-focus source:Q-SN/root-focus/delay
  #:Q-terminal source:Q-SN/terminal/delay
  #:Q-Z Q-SN/Z/stages/delay
  #:commutes Q-SN/refocus-commutes/stages/delay?)

(define-machine-representation-map
  #:source s:delay/staged-row/S
  #:target n:delay/staged-row/N
  #:Q-Z Q-SN/Z/stages/delay
  #:Q-focus source:Q-SN/focus/delay
  #:Q-root-focus source:Q-SN/root-focus/delay
  #:Q-terminal source:Q-SN/terminal/delay
  #:Q-M Q-SN/M/stages/delay
  #:commutes Q-SN/machineize-commutes/stages/delay?)

(define-compressed-representation-map
  #:source s:delay/staged-row/S
  #:target n:delay/staged-row/N
  #:Q-M Q-SN/M/stages/delay
  #:Q-focus source:Q-SN/focus/delay
  #:Q-root-focus source:Q-SN/root-focus/delay
  #:Q-failure-focus source:Q-SN/failure-focus/delay
  #:Q-terminal source:Q-SN/terminal/delay
  #:Q-B Q-SN/B/stages/delay
  #:commutes Q-SN/compress-commutes/stages/delay?)

(define-fixed-point-representation-map
  #:source s:delay/staged-row/S
  #:target n:delay/staged-row/N
  #:Q-B Q-SN/B/stages/delay
  #:Q-terminal source:Q-SN/terminal/delay
  #:Q-Big Q-SN/Big/stages/delay
  #:commutes Q-SN/big-commutes/stages/delay?)

(define (Q-SN/D-composition/stages/delay? decomposition)
  (equal? (Q-SN/D/stages/delay decomposition)
          (Q-EN/D/stages/delay
           (Q-SE/D/stages/delay decomposition))))

(define (Q-SN/Z-composition/stages/delay? refocused)
  (equal? (Q-SN/Z/stages/delay refocused)
          (Q-EN/Z/stages/delay
           (Q-SE/Z/stages/delay refocused))))

(define (Q-SN/M-composition/stages/delay? machine)
  (equal? (Q-SN/M/stages/delay machine)
          (Q-EN/M/stages/delay
           (Q-SE/M/stages/delay machine))))

(define (Q-SN/B-composition/stages/delay? compressed)
  (equal? (Q-SN/B/stages/delay compressed)
          (Q-EN/B/stages/delay
           (Q-SE/B/stages/delay compressed))))

(define (Q-SN/Big-composition/stages/delay? big)
  (equal? (Q-SN/Big/stages/delay big)
          (Q-EN/Big/stages/delay
           (Q-SE/Big/stages/delay big))))
