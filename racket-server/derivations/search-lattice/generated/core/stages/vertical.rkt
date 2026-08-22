#lang racket

(require "../../../framework/core-stage-schema.rkt"
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
 Q-SE/D/stages
 Q-SE/Z/stages
 Q-SE/M/stages
 Q-SE/B/stages
 Q-SE/Big/stages
 Q-EN/D/stages
 Q-EN/Z/stages
 Q-EN/M/stages
 Q-EN/B/stages
 Q-EN/Big/stages
 Q-SN/D/stages
 Q-SN/Z/stages
 Q-SN/M/stages
 Q-SN/B/stages
 Q-SN/Big/stages
 Q-SE/decompose-commutes/stages?
 Q-SE/refocus-commutes/stages?
 Q-SE/machineize-commutes/stages?
 Q-SE/compress-commutes/stages?
 Q-SE/big-commutes/stages?
 Q-EN/decompose-commutes/stages?
 Q-EN/refocus-commutes/stages?
 Q-EN/machineize-commutes/stages?
 Q-EN/compress-commutes/stages?
 Q-EN/big-commutes/stages?
 Q-SN/decompose-commutes/stages?
 Q-SN/refocus-commutes/stages?
 Q-SN/machineize-commutes/stages?
 Q-SN/compress-commutes/stages?
 Q-SN/big-commutes/stages?
 Q-SN/D-composition/stages?
 Q-SN/Z-composition/stages?
 Q-SN/M-composition/stages?
 Q-SN/B-composition/stages?
 Q-SN/Big-composition/stages?)

;; Every map below is emitted by the transformer that owns its target phase.
;; The source layer supplies joint representation views for ordinary focused
;; payloads, root payloads, failure summaries, and terminals.  No phase map is
;; implemented by decoding to an earlier coordinate.

(define-decomposition-representation-map
  #:source s:core/stage/D/S
  #:target e:core/stage/D/E
  #:Q-R source:Q-SE/generated
  #:Q-focus source:Q-SE/focus/generated
  #:Q-root-focus source:Q-SE/root-focus/generated
  #:Q-terminal source:Q-SE/terminal/generated
  #:Q-D Q-SE/D/stages
  #:commutes Q-SE/decompose-commutes/stages?)

(define-refocused-representation-map
  #:source s:core/stage/Z/S
  #:target e:core/stage/Z/E
  #:Q-D Q-SE/D/stages
  #:Q-focus source:Q-SE/focus/generated
  #:Q-root-focus source:Q-SE/root-focus/generated
  #:Q-terminal source:Q-SE/terminal/generated
  #:Q-Z Q-SE/Z/stages
  #:commutes Q-SE/refocus-commutes/stages?)

(define-machine-representation-map
  #:source s:core/stage/M/S
  #:target e:core/stage/M/E
  #:Q-Z Q-SE/Z/stages
  #:Q-focus source:Q-SE/focus/generated
  #:Q-root-focus source:Q-SE/root-focus/generated
  #:Q-terminal source:Q-SE/terminal/generated
  #:Q-M Q-SE/M/stages
  #:commutes Q-SE/machineize-commutes/stages?)

(define-compressed-representation-map
  #:source s:core/stage/B/S
  #:target e:core/stage/B/E
  #:Q-M Q-SE/M/stages
  #:Q-focus source:Q-SE/focus/generated
  #:Q-failure-focus source:Q-SE/failure-focus/generated
  #:Q-terminal source:Q-SE/terminal/generated
  #:Q-B Q-SE/B/stages
  #:commutes Q-SE/compress-commutes/stages?)

(define-fixed-point-representation-map
  #:source s:core/stage/Big/S
  #:target e:core/stage/Big/E
  #:Q-B Q-SE/B/stages
  #:Q-terminal source:Q-SE/terminal/generated
  #:Q-Big Q-SE/Big/stages
  #:commutes Q-SE/big-commutes/stages?)

(define-decomposition-representation-map
  #:source e:core/stage/D/E
  #:target n:core/stage/D/N
  #:Q-R source:Q-EN/generated
  #:Q-focus source:Q-EN/focus/generated
  #:Q-root-focus source:Q-EN/root-focus/generated
  #:Q-terminal source:Q-EN/terminal/generated
  #:Q-D Q-EN/D/stages
  #:commutes Q-EN/decompose-commutes/stages?)

(define-refocused-representation-map
  #:source e:core/stage/Z/E
  #:target n:core/stage/Z/N
  #:Q-D Q-EN/D/stages
  #:Q-focus source:Q-EN/focus/generated
  #:Q-root-focus source:Q-EN/root-focus/generated
  #:Q-terminal source:Q-EN/terminal/generated
  #:Q-Z Q-EN/Z/stages
  #:commutes Q-EN/refocus-commutes/stages?)

(define-machine-representation-map
  #:source e:core/stage/M/E
  #:target n:core/stage/M/N
  #:Q-Z Q-EN/Z/stages
  #:Q-focus source:Q-EN/focus/generated
  #:Q-root-focus source:Q-EN/root-focus/generated
  #:Q-terminal source:Q-EN/terminal/generated
  #:Q-M Q-EN/M/stages
  #:commutes Q-EN/machineize-commutes/stages?)

(define-compressed-representation-map
  #:source e:core/stage/B/E
  #:target n:core/stage/B/N
  #:Q-M Q-EN/M/stages
  #:Q-focus source:Q-EN/focus/generated
  #:Q-failure-focus source:Q-EN/failure-focus/generated
  #:Q-terminal source:Q-EN/terminal/generated
  #:Q-B Q-EN/B/stages
  #:commutes Q-EN/compress-commutes/stages?)

(define-fixed-point-representation-map
  #:source e:core/stage/Big/E
  #:target n:core/stage/Big/N
  #:Q-B Q-EN/B/stages
  #:Q-terminal source:Q-EN/terminal/generated
  #:Q-Big Q-EN/Big/stages
  #:commutes Q-EN/big-commutes/stages?)

;; Direct S-to-N maps consume only S and N views/stages.  They do not call or
;; import either adjacent stage map; composition is checked separately below.
(define-decomposition-representation-map
  #:source s:core/stage/D/S
  #:target n:core/stage/D/N
  #:Q-R source:Q-SN/generated
  #:Q-focus source:Q-SN/focus/generated
  #:Q-root-focus source:Q-SN/root-focus/generated
  #:Q-terminal source:Q-SN/terminal/generated
  #:Q-D Q-SN/D/stages
  #:commutes Q-SN/decompose-commutes/stages?)

(define-refocused-representation-map
  #:source s:core/stage/Z/S
  #:target n:core/stage/Z/N
  #:Q-D Q-SN/D/stages
  #:Q-focus source:Q-SN/focus/generated
  #:Q-root-focus source:Q-SN/root-focus/generated
  #:Q-terminal source:Q-SN/terminal/generated
  #:Q-Z Q-SN/Z/stages
  #:commutes Q-SN/refocus-commutes/stages?)

(define-machine-representation-map
  #:source s:core/stage/M/S
  #:target n:core/stage/M/N
  #:Q-Z Q-SN/Z/stages
  #:Q-focus source:Q-SN/focus/generated
  #:Q-root-focus source:Q-SN/root-focus/generated
  #:Q-terminal source:Q-SN/terminal/generated
  #:Q-M Q-SN/M/stages
  #:commutes Q-SN/machineize-commutes/stages?)

(define-compressed-representation-map
  #:source s:core/stage/B/S
  #:target n:core/stage/B/N
  #:Q-M Q-SN/M/stages
  #:Q-focus source:Q-SN/focus/generated
  #:Q-failure-focus source:Q-SN/failure-focus/generated
  #:Q-terminal source:Q-SN/terminal/generated
  #:Q-B Q-SN/B/stages
  #:commutes Q-SN/compress-commutes/stages?)

(define-fixed-point-representation-map
  #:source s:core/stage/Big/S
  #:target n:core/stage/Big/N
  #:Q-B Q-SN/B/stages
  #:Q-terminal source:Q-SN/terminal/generated
  #:Q-Big Q-SN/Big/stages
  #:commutes Q-SN/big-commutes/stages?)

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
