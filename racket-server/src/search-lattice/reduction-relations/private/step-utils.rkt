#lang racket

(require redex/reduction-semantics)

(provide step-once/deterministic)

(define STEP-PRIORITY-PAIRS
  '(("core/continue-scoped-conj" "core/conj-distribute-state")
    ("disj-seq/distribute-over-conj" "core/conj-distribute-state")
    ("search-base-seq/distribute-over-conj" "core/conj-distribute-state")))

(define (tagged-step-name step)
  (match step
    [(list name _) (~a name)]
    [_ ""]))

(define (resolve-priority steps)
  (or (for/first ([pr (in-list STEP-PRIORITY-PAIRS)])
        (match-define (list preferred loser) pr)
        (define preferred-steps
          (filter (lambda (step)
                    (string=? (tagged-step-name step) preferred))
                  steps))
        (define loser-steps
          (filter (lambda (step)
                    (string=? (tagged-step-name step) loser))
                  steps))
        (and (pair? preferred-steps)
             (pair? loser-steps)
             (= (+ (length preferred-steps) (length loser-steps))
                (length steps))
             preferred-steps))
      steps))

(define (step-once/deterministic rel prog)
  (define named-next*
    (resolve-priority
     (remove-duplicates
      (apply-reduction-relation/tag-with-names rel (term ,prog)))))
  (match named-next*
    ['() '()]
    [(list only-step) (list only-step)]
    [_ (error 'step-once/deterministic
              (format "nondeterministic next-step set for ~v: ~v"
                      prog
                      named-next*))]))
