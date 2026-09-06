#lang racket

(require rackunit redex/reduction-semantics
         "source.rkt" "stages.rkt"
         "../shared/stages/schema.rkt"
         (only-in "../test-support/stage-checks.rkt" check-row)
         (only-in "../shared/kernel.rkt" owners-append)
         (only-in "../shared/wf.rkt" wf-s?)
         (prefix-in q: "../shared/maps.rkt")
         (prefix-in s: "../matrix/source-s.rkt")
         (prefix-in corpus: "../test-support/corpus.rkt")
         (only-in "../test-support/witnesses.rkt"
                  validation-witnesses witness-name witness-initial)
         (only-in "../test-support/frontiers.rkt" pending?))

;; These tests compare every intermediate source state and its unique labelled
;; edge. The only permitted stutter is the old prefix-value contraction;
;; matching final answers alone would miss changes to allocation or strictness.
(define (check-source-bridge initial)
  (define source-edges (s:s-trace initial))
  (define source-states (cons initial (map second source-edges)))
  (for ([state (in-list source-states)])
    (check-true (wf-s? state))
    (check-true (redex-match? ScopeS q (erase-prefixes state)))
    (check-true (wf-s? (erase-prefixes state))))
  (for ([before (in-list source-states)] [edge (in-list source-edges)])
    (match-define (list label after) edge)
    (if (equal? label "prefix-value")
        (check-equal? (erase-prefixes before) (erase-prefixes after))
        (check-equal?
         (apply-reduction-relation/tag-with-names retained-red (erase-prefixes before))
         (list (list label (erase-prefixes after))))))
  (define expected-edges
    (for/list ([edge (in-list source-edges)]
               #:unless (equal? (first edge) "prefix-value"))
      (list (first edge) (erase-prefixes (second edge)))))
  (check-equal? (retained-trace (erase-prefixes initial)) expected-edges)
  (define final (erase-prefixes (last source-states)))
  (check-equal? (retained-run (erase-prefixes initial)) final)
  final)

(define (check-no-prefix-frames computation)
  (define initial (initial-Z RetainedS computation))
  (for ([configuration
         (in-list (cons initial (map second (z-trace RetainedS initial))))])
    (match-define (Z _ frames) configuration)
    (for ([frame (in-list frames)])
      (check-not-equal? (Frame-kind frame) 'prefix))
    (check-true (wf-s? (readback-Z configuration)))
    (check-equal? (frame-support RetainedS frames)
                  (s:context-support/s (plug-frames (term hole) frames)))))

(define (check-boundaries source-frontier retained-frontier completed [fuel 100])
  (when (zero? fuel) (error 'check-boundaries "public advancement exhausted fuel"))
  ;; Ordinary goal roots agree literally, including suspended computation
  ;; syntax, Owner grouping and tags, complete stores, and Forced markers.
  (check-equal? retained-frontier source-frontier)
  (check-equal? (check-source-bridge `(collect ,source-frontier)) completed)
  (check-equal? (retained-run `(collect ,retained-frontier)) completed)
  (define source-next (s:s-run `(advance ,source-frontier)))
  (define retained-next (check-source-bridge `(advance ,source-frontier)))
  (check-equal? (retained-run `(advance ,retained-frontier)) retained-next)
  (if (pending? source-frontier)
      (check-boundaries source-next retained-next completed (sub1 fuel))
      (begin
        (check-equal? retained-next retained-frontier)
        (check-equal? retained-frontier completed))))

(define state '(state () () () (label "initial")))
(define success '(succeed (label "success")))
(define failure '(fail (label "failure")))
(define fresh
  '(∃ (x:new) (x:new =? (sym "new") (label "new-value")) (label "fresh")))

;; Each wrapper reaches internal forcing through actual strict merge. Empty,
;; One, Yield, Delay, saved-right reuse and an old variable are all represented.
(define (delayed-owner body [binders '(x:old)])
  `((∃ ,binders (suspend ,body (label "suspend")) (label "owner"))
    ∨ ,failure (label "choice")))

(define allocation-goals
  (append
   (for/list ([body (in-list (list failure success
                                   `(,success ∨ ,success (label "two"))
                                   `(suspend ,success (label "nested"))
                                   `(,failure ∨ ,success (label "saved-right"))
                                   '(x:old =? (sym "old") (label "old-value"))
                                   fresh))])
     (delayed-owner body))
   (list (delayed-owner success '())
         `(,(delayed-owner success) ∧ ,fresh (label "fresh-after"))
         `(,(delayed-owner '(x:old =? (sym "old") (label "old-value")))
           ∧ ,fresh (label "delayed-bind"))
         (delayed-owner '(suspend (x:old =? (sym "old") (label "old-value"))
                                 (label "nested-old"))))))

;; Mature a Search while genuinely retaining its ancestor context. Stop before
;; the observer processes the value; this extracts no scope by syntactic guess.
(define (mature-under computation owners [fuel 10000])
  (mature-context `(Forced ,owners (commit ,computation)) fuel))

(define (mature-context computation fuel)
  (match computation
    [`(Forced ,_ (commit ,(? retained-value? value))) value]
    [_
     (when (zero? fuel) (error 'mature-context "eager chunk exhausted fuel"))
     (check-true (wf-s? computation))
     (match (apply-reduction-relation retained-red computation)
       [(list next) (mature-context next (sub1 fuel))]
       [other (error 'mature-context "stuck or nonunique: ~e" other)])]))

(define atomic-focus
  (term-match/single ScopeS [(in-hole C (eval owners a σ)) (term a)]))

(define (atomic-work computation)
  (define edges (retained-trace computation))
  (for/list ([before (in-list (cons computation (map second edges)))]
             [edge (in-list edges)]
             #:when (equal? (first edge) "eval-atom"))
    (atomic-focus before)))

(module+ test
  (define ordinary-inputs
    (remove-duplicates
     (append (map witness-initial validation-witnesses)
             (for/list ([goal (in-list (append corpus:search-corpus allocation-goals))])
               (s:s-initial goal)))))
  (for ([evaluation (in-list ordinary-inputs)] [index (in-naturals)])
    (test-case (format "retained scope exact source/public boundary correspondence ~a" index)
      (define frontier (check-source-bridge `(commit ,evaluation)))
      (define completed (check-source-bridge `(render ,evaluation)))
      (check-equal? completed (s:s-run `(render ,evaluation)))
      (check-boundaries (s:s-run `(commit ,evaluation)) frontier completed)))

  ;; Existing generic derivations operate on this source directly. No stage
  ;; transition invokes the pending-prefix machine or its translation.
  (for ([evaluation (in-list ordinary-inputs)] [index (in-naturals)])
    (test-case (format "retained R-D-Z-M-B native stage squares ~a" index)
      (define query `(commit ,evaluation))
      (define frontier (retained-run query))
      (for ([operation (in-list (list query `(advance ,frontier) `(collect ,frontier)))])
        (check-row RetainedS retained-red operation)
        (check-no-prefix-frames operation))))

  (test-case "internal force transfers saved scope before resumption work"
    (define saved '(Owners (Owner (u:2 u:0) (label "saved"))
                           (Owner () (label "empty-saved"))))
    (define body `(eval (Owners) ,fresh ,state))
    (define input `(Forced (Owners (Owner (u:9) (label "ancestor")))
                           (commit (force (Delay ,saved ,body)))))
    (check-source-bridge input)
    (check-equal?
     (map first (retained-trace input))
     '("force-delay" "allocate-fresh" "eval-atom" "commit-one"))
    (check-equal?
     (map first (s:s-trace input))
     '("force-delay" "allocate-fresh" "eval-atom" "prefix-value" "commit-one"))
    (match-define (list "force-delay" after-force) (first (retained-trace input)))
    (check-equal? after-force
                  `(Forced (Owners (Owner (u:9) (label "ancestor")))
                           (commit (eval ,saved ,fresh ,state))))
    (check-no-prefix-frames input))

  (test-case "root scope transport preserves support, allocation and every Search constructor"
    (define ancestor '(Owners (Owner (u:9) (label "ancestor"))))
    (define saved '(Owners (Owner (u:2 u:0) (label "saved"))
                           (Owner () (label "empty-saved"))))
    (define local '(Owners (Owner () (label "empty-local"))))
    (define goal-work `(eval ,local ,fresh ,state))
    (define answer `(Answer (Owners (Owner (u:1) (label "head-only"))) ,state))
    (define computations
      (list `(Empty ,local) `(One ,local ,state)
            `(Yield ,local ,answer ,goal-work)
            `(Delay ,local ,goal-work)
            goal-work
            `(mplus ,local (Empty (Owners)) ,goal-work)
            `(mplus ,local (One (Owners) ,state) ,goal-work)
            `(bind ,local (One (Owners) ,state) ,fresh)
            `(bind ,local (Yield (Owners) (Answer (Owners) ,state)
                               (One (Owners) ,state)) ,fresh)
            `(force (Delay ,local ,goal-work))))
    (for* ([prefix (in-list (list '(Owners)
                                 '(Owners (Owner () (label "only-empty"))) saved))]
           [computation (in-list computations)])
      (define inherited (owners-append ancestor prefix))
      (define raw (mature-under computation inherited))
      (define lifted (lift-owners prefix computation))
      (define result (mature-under lifted ancestor))
      (check-equal? result (s:prefix/s prefix raw))
      (define prefix-names
        (match prefix [`(Owners ,groups ...) (append-map second groups)]))
      (check-equal? (q:Q-SE result '(u:9))
                    (q:Q-SE raw (append '(u:9) prefix-names)))
      (check-equal? (q:Q-SN result '(u:9))
                    (q:Q-SN raw (append '(u:9) prefix-names)))
      (check-source-bridge `(Forced ,ancestor (commit (prefix ,prefix ,computation)))))
    ;; The head's private u:1 does not occupy the residual's allocation world.
    (match-define `(Yield ,_ ,_ (One ,tail-owners ,_))
      (mature-under (lift-owners saved `(Yield ,local ,answer ,goal-work)) ancestor))
    (check-equal? tail-owners
                  '(Owners (Owner () (label "empty-local"))
                           (Owner (u:1) (label "fresh")))))

  (test-case "strict disjunction, eager bind and commitment keep their original boundaries"
    (define left '(succeed (label "left")))
    (define right '(succeed (label "right")))
    (define continuation '(succeed (label "continue")))
    (define query
      (retained-query-initial `((,left ∨ ,right (label "choice"))
                                ∧ ,continuation (label "bind"))))
    (check-equal? (atomic-work query) (list left right continuation continuation))
    (define delayed (retained-query-initial `(suspend ,left (label "delay"))))
    (check-equal? (atomic-work delayed) '())
    (define frontier (retained-run delayed))
    (check-true (pending? frontier))
    (check-equal? (atomic-work `(advance ,frontier)) (list left))
    (check-equal? (atomic-work `(commit (Yield (Owners) (Answer (Owners) ,state)
                                            (Delay (Owners) (eval (Owners) ,right ,state)))))
                  '())
    (check-equal?
     (retained-run
      (retained-query-initial `((,left ∨ ,right (label "choice"))
                                ∧ ,failure (label "unsettled"))))
     '(Done (Owners)))))
