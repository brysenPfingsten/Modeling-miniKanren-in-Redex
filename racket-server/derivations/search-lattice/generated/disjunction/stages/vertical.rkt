#lang racket

(require "../../../framework/core-stage-schema.rkt"
         (prefix-in source: "../source/vertical.rkt")
         (prefix-in s: "s.rkt")
         (prefix-in e: "e.rkt")
         (prefix-in n: "n.rkt"))

(provide
 (rename-out [source:Q-SE/R/disjunction Q-SE/R/stages/disjunction]
             [source:Q-EN/R/disjunction Q-EN/R/stages/disjunction]
             [source:Q-SN/R/disjunction Q-SN/R/stages/disjunction]
             [source:Q-SN/R-composition/disjunction?
              Q-SN/R-composition/stages/disjunction?])
 Q-SE/D/stages/disjunction
 Q-SE/Z/stages/disjunction
 Q-SE/M/stages/disjunction
 Q-SE/B/stages/disjunction
 Q-SE/Big/stages/disjunction
 Q-EN/D/stages/disjunction
 Q-EN/Z/stages/disjunction
 Q-EN/M/stages/disjunction
 Q-EN/B/stages/disjunction
 Q-EN/Big/stages/disjunction
 Q-SN/D/stages/disjunction
 Q-SN/Z/stages/disjunction
 Q-SN/M/stages/disjunction
 Q-SN/B/stages/disjunction
 Q-SN/Big/stages/disjunction
 Q-SE/decompose-commutes/stages/disjunction?
 Q-SE/refocus-commutes/stages/disjunction?
 Q-SE/machineize-commutes/stages/disjunction?
 Q-SE/compress-commutes/stages/disjunction?
 Q-SE/big-commutes/stages/disjunction?
 Q-EN/decompose-commutes/stages/disjunction?
 Q-EN/refocus-commutes/stages/disjunction?
 Q-EN/machineize-commutes/stages/disjunction?
 Q-EN/compress-commutes/stages/disjunction?
 Q-EN/big-commutes/stages/disjunction?
 Q-SN/decompose-commutes/stages/disjunction?
 Q-SN/refocus-commutes/stages/disjunction?
 Q-SN/machineize-commutes/stages/disjunction?
 Q-SN/compress-commutes/stages/disjunction?
 Q-SN/big-commutes/stages/disjunction?
 Q-SN/D-composition/stages/disjunction?
 Q-SN/Z-composition/stages/disjunction?
 Q-SN/M-composition/stages/disjunction?
 Q-SN/B-composition/stages/disjunction?
 Q-SN/Big-composition/stages/disjunction?)

;; Each direct phase map consumes the two extended staged rows and the joint
;; Disjunction source views.  No map decodes through an earlier coordinate.
(define-decomposition-representation-map
  #:source s:disjunction/staged-row/S
  #:target e:disjunction/staged-row/E
  #:Q-R source:Q-SE/R/disjunction
  #:Q-focus source:Q-SE/focus/disjunction
  #:Q-root-focus source:Q-SE/root-focus/disjunction
  #:Q-terminal source:Q-SE/terminal/disjunction
  #:Q-D Q-SE/D/stages/disjunction
  #:commutes Q-SE/decompose-commutes/stages/disjunction?)

(define-refocused-representation-map
  #:source s:disjunction/staged-row/S
  #:target e:disjunction/staged-row/E
  #:Q-D Q-SE/D/stages/disjunction
  #:Q-focus source:Q-SE/focus/disjunction
  #:Q-root-focus source:Q-SE/root-focus/disjunction
  #:Q-terminal source:Q-SE/terminal/disjunction
  #:Q-Z Q-SE/Z/stages/disjunction
  #:commutes Q-SE/refocus-commutes/stages/disjunction?)

(define-machine-representation-map
  #:source s:disjunction/staged-row/S
  #:target e:disjunction/staged-row/E
  #:Q-Z Q-SE/Z/stages/disjunction
  #:Q-focus source:Q-SE/focus/disjunction
  #:Q-root-focus source:Q-SE/root-focus/disjunction
  #:Q-terminal source:Q-SE/terminal/disjunction
  #:Q-M Q-SE/M/stages/disjunction
  #:commutes Q-SE/machineize-commutes/stages/disjunction?)

(define-compressed-representation-map
  #:source s:disjunction/staged-row/S
  #:target e:disjunction/staged-row/E
  #:Q-M Q-SE/M/stages/disjunction
  #:Q-focus source:Q-SE/focus/disjunction
  #:Q-root-focus source:Q-SE/root-focus/disjunction
  #:Q-failure-focus source:Q-SE/failure-focus/disjunction
  #:Q-terminal source:Q-SE/terminal/disjunction
  #:Q-B Q-SE/B/stages/disjunction
  #:commutes Q-SE/compress-commutes/stages/disjunction?)

(define-fixed-point-representation-map
  #:source s:disjunction/staged-row/S
  #:target e:disjunction/staged-row/E
  #:Q-B Q-SE/B/stages/disjunction
  #:Q-terminal source:Q-SE/terminal/disjunction
  #:Q-Big Q-SE/Big/stages/disjunction
  #:commutes Q-SE/big-commutes/stages/disjunction?)

(define-decomposition-representation-map
  #:source e:disjunction/staged-row/E
  #:target n:disjunction/staged-row/N
  #:Q-R source:Q-EN/R/disjunction
  #:Q-focus source:Q-EN/focus/disjunction
  #:Q-root-focus source:Q-EN/root-focus/disjunction
  #:Q-terminal source:Q-EN/terminal/disjunction
  #:Q-D Q-EN/D/stages/disjunction
  #:commutes Q-EN/decompose-commutes/stages/disjunction?)

(define-refocused-representation-map
  #:source e:disjunction/staged-row/E
  #:target n:disjunction/staged-row/N
  #:Q-D Q-EN/D/stages/disjunction
  #:Q-focus source:Q-EN/focus/disjunction
  #:Q-root-focus source:Q-EN/root-focus/disjunction
  #:Q-terminal source:Q-EN/terminal/disjunction
  #:Q-Z Q-EN/Z/stages/disjunction
  #:commutes Q-EN/refocus-commutes/stages/disjunction?)

(define-machine-representation-map
  #:source e:disjunction/staged-row/E
  #:target n:disjunction/staged-row/N
  #:Q-Z Q-EN/Z/stages/disjunction
  #:Q-focus source:Q-EN/focus/disjunction
  #:Q-root-focus source:Q-EN/root-focus/disjunction
  #:Q-terminal source:Q-EN/terminal/disjunction
  #:Q-M Q-EN/M/stages/disjunction
  #:commutes Q-EN/machineize-commutes/stages/disjunction?)

(define-compressed-representation-map
  #:source e:disjunction/staged-row/E
  #:target n:disjunction/staged-row/N
  #:Q-M Q-EN/M/stages/disjunction
  #:Q-focus source:Q-EN/focus/disjunction
  #:Q-root-focus source:Q-EN/root-focus/disjunction
  #:Q-failure-focus source:Q-EN/failure-focus/disjunction
  #:Q-terminal source:Q-EN/terminal/disjunction
  #:Q-B Q-EN/B/stages/disjunction
  #:commutes Q-EN/compress-commutes/stages/disjunction?)

(define-fixed-point-representation-map
  #:source e:disjunction/staged-row/E
  #:target n:disjunction/staged-row/N
  #:Q-B Q-EN/B/stages/disjunction
  #:Q-terminal source:Q-EN/terminal/disjunction
  #:Q-Big Q-EN/Big/stages/disjunction
  #:commutes Q-EN/big-commutes/stages/disjunction?)

;; Direct S-to-N maps use only the S and N views/rows.  Equality with the
;; adjacent composition is a separate executable obligation below.
(define-decomposition-representation-map
  #:source s:disjunction/staged-row/S
  #:target n:disjunction/staged-row/N
  #:Q-R source:Q-SN/R/disjunction
  #:Q-focus source:Q-SN/focus/disjunction
  #:Q-root-focus source:Q-SN/root-focus/disjunction
  #:Q-terminal source:Q-SN/terminal/disjunction
  #:Q-D Q-SN/D/stages/disjunction
  #:commutes Q-SN/decompose-commutes/stages/disjunction?)

(define-refocused-representation-map
  #:source s:disjunction/staged-row/S
  #:target n:disjunction/staged-row/N
  #:Q-D Q-SN/D/stages/disjunction
  #:Q-focus source:Q-SN/focus/disjunction
  #:Q-root-focus source:Q-SN/root-focus/disjunction
  #:Q-terminal source:Q-SN/terminal/disjunction
  #:Q-Z Q-SN/Z/stages/disjunction
  #:commutes Q-SN/refocus-commutes/stages/disjunction?)

(define-machine-representation-map
  #:source s:disjunction/staged-row/S
  #:target n:disjunction/staged-row/N
  #:Q-Z Q-SN/Z/stages/disjunction
  #:Q-focus source:Q-SN/focus/disjunction
  #:Q-root-focus source:Q-SN/root-focus/disjunction
  #:Q-terminal source:Q-SN/terminal/disjunction
  #:Q-M Q-SN/M/stages/disjunction
  #:commutes Q-SN/machineize-commutes/stages/disjunction?)

(define-compressed-representation-map
  #:source s:disjunction/staged-row/S
  #:target n:disjunction/staged-row/N
  #:Q-M Q-SN/M/stages/disjunction
  #:Q-focus source:Q-SN/focus/disjunction
  #:Q-root-focus source:Q-SN/root-focus/disjunction
  #:Q-failure-focus source:Q-SN/failure-focus/disjunction
  #:Q-terminal source:Q-SN/terminal/disjunction
  #:Q-B Q-SN/B/stages/disjunction
  #:commutes Q-SN/compress-commutes/stages/disjunction?)

(define-fixed-point-representation-map
  #:source s:disjunction/staged-row/S
  #:target n:disjunction/staged-row/N
  #:Q-B Q-SN/B/stages/disjunction
  #:Q-terminal source:Q-SN/terminal/disjunction
  #:Q-Big Q-SN/Big/stages/disjunction
  #:commutes Q-SN/big-commutes/stages/disjunction?)

(define (Q-SN/D-composition/stages/disjunction? decomposition)
  (equal? (Q-SN/D/stages/disjunction decomposition)
          (Q-EN/D/stages/disjunction
           (Q-SE/D/stages/disjunction decomposition))))

(define (Q-SN/Z-composition/stages/disjunction? refocused)
  (equal? (Q-SN/Z/stages/disjunction refocused)
          (Q-EN/Z/stages/disjunction
           (Q-SE/Z/stages/disjunction refocused))))

(define (Q-SN/M-composition/stages/disjunction? machine)
  (equal? (Q-SN/M/stages/disjunction machine)
          (Q-EN/M/stages/disjunction
           (Q-SE/M/stages/disjunction machine))))

(define (Q-SN/B-composition/stages/disjunction? compressed)
  (equal? (Q-SN/B/stages/disjunction compressed)
          (Q-EN/B/stages/disjunction
           (Q-SE/B/stages/disjunction compressed))))

(define (Q-SN/Big-composition/stages/disjunction? big)
  (equal? (Q-SN/Big/stages/disjunction big)
          (Q-EN/Big/stages/disjunction
           (Q-SE/Big/stages/disjunction big))))
