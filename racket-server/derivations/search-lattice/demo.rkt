#lang racket

(require racket/pretty
         redex/reduction-semantics
         (prefix-in s: "./core/s/decomposition.rkt")
         (prefix-in z: "./core/s/refocused.rkt")
         (prefix-in m: "./core/s/machine.rkt")
         (prefix-in b: "./core/s/compressed.rkt")
         (prefix-in big: "./core/s/fixed-point.rkt")
         (prefix-in big-spec: "./core/s/fixed-point-spec.rkt")
         (prefix-in e: "./core/e/decomposition.rkt")
         (prefix-in q: "./core/s-to-e.rkt"))

(provide demo-source/s
         compression-witness
         seed-snapshot)

(define sigma
  (term (state () () () (label "state"))))

;; The gap at u:1 makes the allocator boundary visible: S derives the live
;; support from the separated owner-bearing context, while E reads the same
;; cumulative support from its focused Work node.  Both choose u:1.
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

(define source/e
  (term (q:Q-SE/F ,demo-source/s)))

(define decomposition/e
  (first
   (judgment-holds (e:decompose/e ,source/e D) D)))

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
    (e:decomposed-step/e
     ,decomposition/e
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
   (list 'R/E source/e)
   (list 'D/E decomposition/e)
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
                  R/E
                  D/E
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
  (check-equal? (term (big-spec:flatten-BTrace/s
                       ,(first big-certificate/s)))
                '(allocate-fresh
                  unify-success
                  conj-return
                  disequality-success
                  finish-success))
  (check-true (q:source-square/raw?/s->e demo-source/s)))
