#lang racket

(require rackunit
         rackunit/text-ui
         redex/reduction-semantics
         (prefix-in core:
                    "../../../src/search-lattice/languages/core-lang.rkt")
         (prefix-in delay:
                    "../../../src/search-lattice/languages/delay-lang.rkt")
         (prefix-in disj:
                    "../../../src/search-lattice/languages/disj-lang.rkt")
         (prefix-in search:
                    "../../../src/search-lattice/languages/search-lang.rkt")
         (prefix-in rail:
                    "../../../src/search-lattice/languages/rail-lang.rkt")
         (prefix-in search-red:
                    "../../../src/search-lattice/reduction-relations/search-red.rkt")
         (prefix-in rail-red:
                    "../../../src/search-lattice/reduction-relations/rail-red.rkt"))

(provide FRAME-GRAMMAR)

(define sigma
  (term (state () () () (label "state"))))

(define core-owner-slot-match
  (redex-match core:core-lang (in-hole WorkOwnerSlot owners)))
(define delay-owner-slot-match
  (redex-match delay:delay-lang (in-hole WorkOwnerSlot owners)))
(define disj-owner-slot-match
  (redex-match disj:disj-lang (in-hole WorkOwnerSlot owners)))
(define search-owner-slot-match
  (redex-match search:search-lang (in-hole WorkOwnerSlot owners)))
(define rail-owner-slot-match
  (redex-match rail:rail-lang (in-hole WorkOwnerSlot owners)))

(define core-work-path-match
  (redex-match core:core-lang WorkPath))
(define delay-work-path-match
  (redex-match delay:delay-lang WorkPath))
(define disj-work-path-match
  (redex-match disj:disj-lang WorkPath))
(define search-work-path-match
  (redex-match search:search-lang WorkPath))
(define rail-work-path-match
  (redex-match rail:rail-lang WorkPath))
(define core-spine-context-match
  (redex-match core:core-lang SpineContext))
(define delay-spine-context-match
  (redex-match delay:delay-lang SpineContext))
(define disj-spine-context-match
  (redex-match disj:disj-lang SpineContext))
(define search-spine-context-match
  (redex-match search:search-lang SpineContext))
(define rail-spine-context-match
  (redex-match rail:rail-lang SpineContext))
(define core-work-focus-match
  (redex-match core:core-lang WorkFocus))
(define delay-work-focus-match
  (redex-match delay:delay-lang WorkFocus))
(define disj-work-focus-match
  (redex-match disj:disj-lang WorkFocus))
(define search-work-focus-match
  (redex-match search:search-lang WorkFocus))
(define rail-work-focus-match
  (redex-match rail:rail-lang WorkFocus))
(define core-goal-match
  (redex-match core:core-lang g))
(define delay-goal-match
  (redex-match delay:delay-lang g))
(define disj-goal-match
  (redex-match disj:disj-lang g))
(define search-goal-match
  (redex-match search:search-lang g))
(define rail-goal-match
  (redex-match rail:rail-lang g))

(define (match-count matcher datum)
  (match (matcher datum)
    [#f 0]
    [matches (length matches)]))

(define (sequences alphabet max-length [prefix '()])
  (cons prefix
        (cond
          [(= (length prefix) max-length) '()]
          [else
           (append-map
            (lambda (item)
              (sequences alphabet
                         max-length
                         (append prefix (list item))))
            alphabet)])))

(define (owners-for owned?)
  (if owned?
      '(Owners (Owner (u:o) (label "owner")))
      '(Owners)))

(define (spine-wrap kind body)
  (match kind
    [(list 'forced owned?)
     `(Forced ,(owners-for owned?) ,body)]
    [(list 'emit owned?)
     `(Emit ,(owners-for owned?) (Answer (Owners) ,sigma) ,body)]))

(define (work-wrap kind body)
  (match kind
    [(list 'conj owned?)
     `(Conj ,(owners-for owned?)
            ,body
            (succeed (label "consequence")))]
    [(list 'disj-left owned?)
     `(DisjL ,(owners-for owned?) ,body (Dead (Owners)))]
    [(list 'disj-right owned?)
     `(DisjR ,(owners-for owned?) (Dead (Owners)) ,body)]))

(define (wrap-all wrap kinds body)
  (for/fold ([body body])
            ([kind (in-list (reverse kinds))])
    (wrap kind body)))

(define (tagged-name successor)
  (match successor
    [(list name _) (~a name)]))

(define/provide-test-suite FRAME-GRAMMAR
  (test-case "WorkOwnerSlot has one root decomposition per constructor"
    (define core-witnesses
      (list
       (term (Work (Owners) (succeed (label "work")) ,sigma))
       (term (Returned (Owners) ,sigma))
       (term (Dead (Owners)))
       (term (Conj (Owners) (Dead (Owners)) (succeed (label "conj"))))))
    (define delay-witness
      (term (PendingDelay (Owners) (Dead (Owners)))))
    (define disj-witness
      (term (DisjL (Owners) (Dead (Owners)) (Dead (Owners)))))
    (define search-witness
      (term (DisjR (Owners) (Dead (Owners)) (Dead (Owners)))))

    (for ([witness (in-list core-witnesses)])
      (check-equal? (match-count core-owner-slot-match witness) 1)
      (check-equal? (match-count delay-owner-slot-match witness) 1)
      (check-equal? (match-count disj-owner-slot-match witness) 1)
      (check-equal? (match-count search-owner-slot-match witness) 1)
      (check-equal? (match-count rail-owner-slot-match witness) 1))
    (check-equal? (match-count core-owner-slot-match delay-witness) 0)
    (check-equal? (match-count delay-owner-slot-match delay-witness) 1)
    (check-equal? (match-count search-owner-slot-match delay-witness) 1)
    (check-equal? (match-count disj-owner-slot-match disj-witness) 1)
    (check-equal? (match-count search-owner-slot-match disj-witness) 1)
    (check-equal? (match-count rail-owner-slot-match delay-witness) 1)
    (check-equal? (match-count rail-owner-slot-match disj-witness) 1)
    (check-equal? (match-count search-owner-slot-match search-witness) 0)
    (check-equal? (match-count rail-owner-slot-match search-witness) 1))

  (test-case "WorkPath composes constructors directly with one derivation"
    (define hole-path (term hole))
    (define conj-path
      (term
       (Conj (Owners)
             (Conj (Owners (Owner (u:o) (label "owner")))
                   hole
                   (succeed (label "inner")))
             (succeed (label "outer")))))
    (define left-choice-path
      (term
       (DisjL (Owners)
              (Conj (Owners) hole (succeed (label "inside")))
              (Dead (Owners)))))
    (define right-choice-path
      (term
       (DisjR (Owners)
              (Dead (Owners))
              (Conj (Owners) hole (succeed (label "inside"))))))

    (for ([matcher (in-list (list core-work-path-match
                                  delay-work-path-match
                                  disj-work-path-match
                                  search-work-path-match
                                  rail-work-path-match))])
      (check-equal? (match-count matcher hole-path) 1)
      (check-equal? (match-count matcher conj-path) 1))
    (check-equal? (match-count core-work-path-match left-choice-path) 0)
    (check-equal? (match-count delay-work-path-match left-choice-path) 0)
    (check-equal? (match-count disj-work-path-match left-choice-path) 1)
    (check-equal? (match-count search-work-path-match left-choice-path) 1)
    (check-equal? (match-count rail-work-path-match left-choice-path) 1)
    (check-equal? (match-count search-work-path-match right-choice-path) 0)
    (check-equal? (match-count rail-work-path-match right-choice-path) 1)
    (check-equal?
     (match-count delay-work-path-match
                  (term (PendingDelay (Owners) hole)))
     0))

  (test-case "SpineContext composes frontier constructors directly with one derivation"
    (define hole-context (term hole))
    (define forced-context
      (term (Forced (Owners) hole)))
    (define emit-context
      (term
       (Emit (Owners)
             (Answer (Owners) ,sigma)
             hole)))
    (define search-context
      (term
       (Forced (Owners)
               (Emit (Owners (Owner (u:e) (label "emit")))
                     (Answer (Owners) ,sigma)
                     hole))))

    (for ([matcher (in-list (list core-spine-context-match
                                  delay-spine-context-match
                                  disj-spine-context-match
                                  search-spine-context-match
                                  rail-spine-context-match))])
      (check-equal? (match-count matcher hole-context) 1))
    (check-equal? (match-count core-spine-context-match forced-context) 0)
    (check-equal? (match-count delay-spine-context-match forced-context) 1)
    (check-equal? (match-count disj-spine-context-match forced-context) 0)
    (check-equal? (match-count search-spine-context-match forced-context) 1)
    (check-equal? (match-count rail-spine-context-match forced-context) 1)
    (check-equal? (match-count core-spine-context-match emit-context) 0)
    (check-equal? (match-count delay-spine-context-match emit-context) 0)
    (check-equal? (match-count disj-spine-context-match emit-context) 1)
    (check-equal? (match-count search-spine-context-match emit-context) 1)
    (check-equal? (match-count rail-spine-context-match emit-context) 1)
    (check-equal? (match-count search-spine-context-match search-context) 1)
    (check-equal? (match-count rail-spine-context-match search-context) 1))

  (test-case "disequality is a direct goal in every primary language"
    (define disequality-goal
      (term (u:left != u:right (label "disequality"))))
    (for ([matcher (in-list (list core-goal-match
                                  delay-goal-match
                                  disj-goal-match
                                  search-goal-match
                                  rail-goal-match))])
      (check-equal? (match-count matcher disequality-goal) 1)))

  (test-case "direct WorkPath and SpineContext extensions are inherited compositionally"
    (define core-focus
      (term (More (Conj (Owners) hole (succeed (label "k"))))))
    (define delay-focus
      (term
       (Forced (Owners (Owner (u:f) (label "forced")))
               (More (Conj (Owners) hole (succeed (label "k")))))))
    (define disj-focus
      (term
       (Emit (Owners)
             (Answer (Owners) ,sigma)
             (More
              (DisjL (Owners (Owner (u:o) (label "choice")))
                     hole
                     (Dead (Owners)))))))
    (define search-focus
      (term
       (Forced (Owners)
               (Emit (Owners (Owner (u:e) (label "emit")))
                     (Answer (Owners) ,sigma)
                     (More
                      (DisjL (Owners)
                             (Conj (Owners)
                                   hole
                                   (succeed (label "k")))
                             (Dead (Owners))))))))
    (define rail-focus
      (term
       (Forced (Owners)
               (Emit (Owners (Owner (u:e) (label "emit")))
                     (Answer (Owners) ,sigma)
                     (More
                      (DisjR (Owners)
                             (Dead (Owners))
                             (Conj (Owners)
                                   hole
                                   (succeed (label "k")))))))))

    (check-equal? (match-count core-work-focus-match core-focus) 1)
    (check-equal? (match-count delay-work-focus-match delay-focus) 1)
    (check-equal? (match-count disj-work-focus-match disj-focus) 1)
    (check-equal? (match-count search-work-focus-match search-focus) 1)
    (check-equal? (match-count search-work-focus-match rail-focus) 0)
    (check-equal? (match-count rail-work-focus-match rail-focus) 1)
    (check-equal?
     (match-count
      search-spine-context-match
      (term
       (Forced (Owners)
               (Emit (Owners (Owner (u:e) (label "emit")))
                     (Answer (Owners) ,sigma)
                     hole))))
     1))

  (test-case "generated composed focus contexts have one raw derivation"
    (define spine-alphabet
      '((forced #f) (forced #t) (emit #f) (emit #t)))
    (define search-work-alphabet
      '((conj #f) (conj #t)
        (disj-left #f) (disj-left #t)))
    (define rail-work-alphabet
      (append search-work-alphabet
              '((disj-right #f) (disj-right #t))))
    (for* ([spine-kinds (in-list (sequences spine-alphabet 2))]
           [work-kinds (in-list (sequences search-work-alphabet 2))])
      (define context
        (wrap-all
         spine-wrap
         spine-kinds
         `(More ,(wrap-all work-wrap work-kinds (term hole)))))
      (check-equal?
       (match-count search-work-focus-match context)
       1
       (format "unexpected search WorkFocus derivation count for ~s" context)))
    (for* ([spine-kinds (in-list (sequences spine-alphabet 2))]
           [work-kinds (in-list (sequences rail-work-alphabet 2))])
      (define context
        (wrap-all
         spine-wrap
         spine-kinds
         `(More ,(wrap-all work-wrap work-kinds (term hole)))))
      (check-equal?
       (match-count rail-work-focus-match context)
       1
       (format "unexpected rail WorkFocus derivation count for ~s" context))))

  (test-case "search and rail relations use their composed focuses"
    (define nested-work
      (term
       (Forced (Owners (Owner (u:f) (label "forced")))
               (Emit (Owners (Owner (u:e) (label "emit")))
                     (Answer (Owners) ,sigma)
                     (More
                      (DisjR (Owners (Owner (u:o) (label "choice")))
                             (Dead (Owners))
                             (Work (Owners (Owner (u:p) (label "payload")))
                                   (succeed (label "ok"))
                                   ,sigma)))))))
    (define nested-next*
      (apply-reduction-relation/tag-with-names
       rail-red:rail-red
       nested-work))
    (check-equal? (length nested-next*) 1)
    (check-equal? (tagged-name (first nested-next*)) "succeed")
    (check-equal?
     (second (first nested-next*))
     (term
      (Forced (Owners (Owner (u:f) (label "forced")))
              (Emit (Owners (Owner (u:e) (label "emit")))
                    (Answer (Owners) ,sigma)
                    (More
                     (DisjR (Owners (Owner (u:o) (label "choice")))
                            (Dead (Owners))
                            (Returned (Owners (Owner (u:p) (label "payload")))
                                      ,sigma)))))))

    (define delayed-boundary
      (term
       (More
        (PendingDelay (Owners (Owner (u:d) (label "delay")))
                      (Work (Owners) (succeed (label "inside")) ,sigma)))))
    (define delayed-next*
      (apply-reduction-relation/tag-with-names
       search-red:search-red
       delayed-boundary))
    (check-equal? (length delayed-next*) 1)
    (check-equal? (tagged-name (first delayed-next*)) "force-delay"))
)

(module+ test
  (run-tests FRAME-GRAMMAR))
