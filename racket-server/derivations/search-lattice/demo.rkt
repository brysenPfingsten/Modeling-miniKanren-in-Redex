#lang racket

(require racket/pretty
         redex/reduction-semantics
         (prefix-in s: "./core/s/decomposition.rkt")
         (prefix-in z: "./core/s/refocused.rkt")
         (prefix-in m: "./core/s/machine.rkt")
         (prefix-in b: "./core/s/compressed.rkt")
         (prefix-in big: "./core/s/fixed-point.rkt")
         (prefix-in big-spec: "./core/s/fixed-point-spec.rkt")
         (prefix-in selected-q: "./generated/core/source/vertical.rkt")
         (prefix-in selected-s: "./generated/core/stages/s.rkt")
         (prefix-in selected-e: "./generated/core/stages/e.rkt")
         (prefix-in selected-stage-q: "./generated/core/stages/vertical.rkt"))

(provide demo-source/s
         compression-witness
         seed-snapshot)

(define sigma
  (term (state () () () (label "state"))))

;; The gap at u:1 makes the selected representation boundary visible: S
;; reconstructs support from the separated owner-bearing world path, while E
;; carries the same ordered support in logical state.  Both allocate u:1.
(define demo-source/s
  (term
   (More
    (Conj
     (Owners (Owner (u:0) (label "outer")))
     (Work
      (Owners (Owner (u:2) (label "inner")))
      (∃ (x:q)
         (x:q =? u:0 (label "body"))
         (label "fresh"))
      ,sigma)
     (u:0 != (nat 7) (label "later"))))))

(define decomposition/s
  (first
   (judgment-holds (s:decompose/s ,demo-source/s D) D)))

(define refocused/s
  (term (z:D->Z/s ,decomposition/s)))

(define machine/s
  (term (m:encode-ZM/s ,refocused/s)))

(define compressed/s
  (term (b:encode-MB/s ,machine/s)))

(define big/s
  (first
   (judgment-holds
    (big:big-evaluate/direct/s ,demo-source/s Big)
    Big)))

(define big-certificate/s
  (first
   (judgment-holds
    (big-spec:big-evaluate/spec/s
     ,demo-source/s
     BTrace
     Big)
    (BTrace Big))))

(define selected-source/e
  (selected-q:Q-SE/generated demo-source/s))

;; The selected columns consume the shared source interface and do not import
;; the handwritten S reference stages above.  The S row is compared with that
;; independent reference; the E row is reached only through the selected
;; phase-local representation maps.
(define selected-decomposition/s
  (first
   (judgment-holds
    (selected-s:generated-stage-decompose/s ,demo-source/s D)
    D)))

(define selected-refocused/s
  (term
   (selected-s:generated-stage-refocus-phase/s
    ,selected-decomposition/s)))

(define selected-machine/s
  (term
   (selected-s:generated-stage-machineize/s ,selected-refocused/s)))

(define selected-compressed/s
  (term
   (selected-s:generated-stage-compress/s ,selected-machine/s)))

(define selected-big/s
  (first
   (judgment-holds
    (selected-s:generated-stage-big-evaluate/direct/s ,demo-source/s Big)
    Big)))

(define selected-decomposition/e
  (first
   (judgment-holds
    (selected-e:generated-stage-decompose/e ,selected-source/e D)
    D)))

(define selected-refocused/e
  (term
   (selected-e:generated-stage-refocus-phase/e
    ,selected-decomposition/e)))

(define selected-machine/e
  (term
   (selected-e:generated-stage-machineize/e ,selected-refocused/e)))

(define selected-compressed/e
  (term
   (selected-e:generated-stage-compress/e ,selected-machine/e)))

(define selected-big/e
  (first
   (judgment-holds
    (selected-e:generated-stage-big-evaluate/direct/e
     ,selected-source/e
     Big)
    Big)))

(define next/s
  (first
   (judgment-holds
    (s:decomposed-step/direct/s
     ,decomposition/s
     RuleName
     D_next)
    (RuleName D_next))))

(define next/e
  (first
   (judgment-holds
    (selected-e:generated-stage-decomposed-step/e
     ,selected-decomposition/e
     RuleName
     D_next)
    (RuleName D_next))))

(define next-m/s
  (first
   (judgment-holds
    (m:machine-step/direct/s
     ,machine/s
     RuleName
     M_next)
    (RuleName M_next))))

(define next-b/s
  (first
   (judgment-holds
    (b:compressed-step/direct/s
     ,compressed/s
     TransitionSpan
     B_next)
    (TransitionSpan B_next))))

;; This second, deliberately tiny witness makes the nontrivial compression
;; visible: the exact M transitions `succeed` and `finish-success` become one
;; B transition carrying both labels as its replay certificate.
(define producer-source/s
  (term
   (More
    (Work
     (Owners)
     (succeed (label "compression-witness"))
     ,sigma))))

(define producer-decomposition/s
  (first
   (judgment-holds (s:decompose/s ,producer-source/s D) D)))

(define producer-machine/s
  (term (m:D->M/s ,producer-decomposition/s)))

(define producer-compressed/s
  (term (b:encode-MB/s ,producer-machine/s)))

(define compression-witness
  (first
   (judgment-holds
    (b:compressed-step/direct/s
     ,producer-compressed/s
     TransitionSpan
     B_next)
    (TransitionSpan B_next))))

(define seed-snapshot
  (list
   (list 'R/S demo-source/s)
   (list 'D/S decomposition/s)
   (list 'Z/S refocused/s)
   (list 'M/S machine/s)
   (list 'B/S compressed/s)
   (list 'Big/S big/s)
   (list 'selected-R/E selected-source/e)
   (list 'selected-D/S selected-decomposition/s)
   (list 'selected-Z/S selected-refocused/s)
   (list 'selected-M/S selected-machine/s)
   (list 'selected-B/S selected-compressed/s)
   (list 'selected-Big/S selected-big/s)
   (list 'selected-D/E selected-decomposition/e)
   (list 'selected-Z/E selected-refocused/e)
   (list 'selected-M/E selected-machine/e)
   (list 'selected-B/E selected-compressed/e)
   (list 'selected-Big/E selected-big/e)
   (list 'next-D/S next/s)
   (list 'next-D/E next/e)
   (list 'next-M/S next-m/s)
   (list 'next-B/S next-b/s)
   (list 'BTrace->Big/S big-certificate/s)
   (list 'two-label-B/S compression-witness)))

(module+ main
  (for ([entry (in-list seed-snapshot)])
    (match-define (list coordinate artifact) entry)
    (displayln coordinate)
    (pretty-write artifact)
    (newline)))

(module+ test
  (require rackunit)

  (check-equal? (map first seed-snapshot)
                '(R/S
                  D/S
                  Z/S
                  M/S
                  B/S
                  Big/S
                  selected-R/E
                  selected-D/S
                  selected-Z/S
                  selected-M/S
                  selected-B/S
                  selected-Big/S
                  selected-D/E
                  selected-Z/E
                  selected-M/E
                  selected-B/E
                  selected-Big/E
                  next-D/S
                  next-D/E
                  next-M/S
                  next-B/S
                  BTrace->Big/S
                  two-label-B/S))
  (check-equal? (first next/s) 'allocate-fresh)
  (check-equal? (first next/e) 'allocate-fresh)
  (check-equal? (first next-m/s) 'allocate-fresh)
  (check-equal? (first next-b/s)
                '(transition-span allocate-fresh))
  (check-equal? (first compression-witness)
                '(transition-span succeed finish-success))
  (check-equal? (second big-certificate/s) big/s)
  (check-equal? selected-decomposition/s decomposition/s)
  (check-equal? selected-refocused/s refocused/s)
  (check-equal? selected-machine/s machine/s)
  (check-equal? selected-compressed/s compressed/s)
  (check-equal? selected-big/s big/s)
  (check-equal? (selected-stage-q:Q-SE/D/stages
                 selected-decomposition/s)
                selected-decomposition/e)
  (check-equal? (selected-stage-q:Q-SE/Z/stages selected-refocused/s)
                selected-refocused/e)
  (check-equal? (selected-stage-q:Q-SE/M/stages selected-machine/s)
                selected-machine/e)
  (check-equal? (selected-stage-q:Q-SE/B/stages selected-compressed/s)
                selected-compressed/e)
  (check-equal? (selected-stage-q:Q-SE/Big/stages selected-big/s)
                selected-big/e)
  (check-equal? (term (big-spec:flatten-BTrace/s
                       ,(first big-certificate/s)))
                '(allocate-fresh
                  unify-success
                  conj-return
                  disequality-success
                  finish-success)))
