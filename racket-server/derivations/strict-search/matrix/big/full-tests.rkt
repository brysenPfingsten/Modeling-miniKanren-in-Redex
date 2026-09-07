#lang racket

(require rackunit redex/reduction-semantics
         "full.rkt" "maps.rkt" "../full-source.rkt" "../stages/full.rkt"
         "../../shared/maps.rkt" "../../shared/wf.rkt"
         "../../shared/stages/schema.rkt" "../../test-support/stage-checks.rkt")

(define definitions
  '((r:eq (x:a x:b) (x:a =? x:b (label "eq-body")))
    (r:walk (x:xs)
            ((x:xs =? empty (label "walk-empty")) ∨
             (∃ (x:a x:rest)
                ((x:xs =? (x:a : x:rest) (label "walk-split")) ∧
                 (r:walk x:rest (label "walk-recursion")) (label "walk-bind"))
                (label "walk-fresh")) (label "walk-choice")))
    (r:even (x:xs)
            ((x:xs =? empty (label "even-empty")) ∨
             (∃ (x:a x:rest)
                ((x:xs =? (x:a : x:rest) (label "even-split")) ∧
                 (r:odd x:rest (label "odd-call")) (label "even-bind"))
                (label "even-fresh")) (label "even-choice")))
    (r:odd (x:xs)
           (∃ (x:a x:rest)
              ((x:xs =? (x:a : x:rest) (label "odd-split")) ∧
               (r:even x:rest (label "even-call")) (label "odd-bind"))
              (label "odd-fresh")))
    (r:shadow (x:q x:other)
              (∃ (x:q x:unused)
                 ((r:eq x:q x:other (label "shadow-alias")) ∧
                  (suspend (r:eq x:other x:q (label "shadow-resume")) (label "shadow-delay"))
                  (label "shadow-bind")) (label "shadow-fresh")))
    (r:repeat (x:q)
              ((r:eq x:q (sym "A") (label "repeat-answer")) ∨
               (suspend (r:repeat x:q (label "repeat-recursion")) (label "explicit-delay"))
               (label "repeat-choice")))
    (r:loop () (r:loop (label "loop")))))

(define rows
  (list (list SRel strict-s-rel-red evaluate-full/s promote-full/s raw-derivations-full/s wf-s-rel?)
        (list ERel strict-e-rel-red evaluate-full/e promote-full/e raw-derivations-full/e wf-e-rel?)
        (list NRel strict-n-rel-red evaluate-full/n promote-full/n raw-derivations-full/n wf-n-rel?)))

(define (source-trace relation current [remaining 10000] [reversed '()])
  (match (apply-reduction-relation/tag-with-names relation current)
    ['() (reverse reversed)]
    [(list (and edge (list _ next)))
     (when (zero? remaining) (error 'source-trace "finite fixture exhausted"))
     (source-trace relation next (sub1 remaining) (cons edge reversed))]
    [edges (error 'source-trace "nonunique native source successors: ~e" edges)]))

(define (check-environment certificate expected)
  (match-define `(program ,input-definitions ,_) (BigCertificate-input certificate))
  (match-define `(program ,output-definitions ,_) (BigCertificate-output certificate))
  (check-equal? input-definitions expected)
  (check-equal? output-definitions expected)
  (for ([premise (in-list (BigCertificate-premises certificate))])
    (check-environment premise expected)))

(define (check-program source)
  (match-define `(program ,environment ,_) source)
  (define inputs (list source (Q-SE source) (Q-SN source)))
  (check-equal? (Q-EN (second inputs)) (third inputs))
  (define results
    (for/list ([row (in-list rows)] [input (in-list inputs)])
      (match-define (list stage relation evaluate promote raw wf?) row)
      (check-true (wf? input))
      (match-define (list value labels) (evaluate input))
      (check-equal? (promote input) value)
      (define edges (source-trace relation input))
      (check-equal? labels (map first edges))
      (check-equal? value (if (null? edges) input (second (last edges))))
      ;; The existing stage gate checks native R/D/Z/M/B configurations and
      ;; exact M span replay. Big independently produces its labeled proof.
      (check-row stage relation input)
      (define b-edges (b-trace stage (initial-B stage input)))
      (check-equal? labels (append-map (lambda (edge) (semantic-labels (first edge))) b-edges))
      (define certificate (certify/raw raw input))
      (check-environment certificate environment)
      (list value certificate)))
  (match-define (list (list s-value s-proof) (list e-value e-proof) (list n-value n-proof)) results)
  (check-equal? (Q-SE s-value) e-value)
  (check-equal? (Q-SN s-value) n-value)
  (check-equal? (Q-EN e-value) n-value)
  (check-equal? (QBig-SE s-proof) e-proof)
  (check-equal? (QBig-EN e-proof) n-proof)
  (check-equal? (QBig-SN s-proof) n-proof)
  (check-equal? (QBig-SN s-proof) (QBig-EN (QBig-SE s-proof)))
  s-value)

(define (advance-query program)
  (match-define `(program ,environment ,frontier) program)
  `(program ,environment (advance ,frontier)))

(define (check-finite-boundaries frontier [remaining 20])
  (when (zero? remaining) (error 'check-finite-boundaries "finite fixture exhausted"))
  (check-equal? (check-program frontier) frontier)
  (match-define `(program ,environment ,body) frontier)
  (define complete (check-program `(program ,environment (collect ,body))))
  (check-true (s-rel-observation? complete))
  (define next (check-program (advance-query frontier)))
  (cond
    [(s-rel-observation? frontier)
     (check-equal? next frontier)
     (check-equal? complete frontier)]
    [else (check-finite-boundaries next (sub1 remaining))]))

(define finite-goals
  (list
   '(r:eq (sym "A") (sym "A") (label "simple-call"))
   '(r:walk ((sym "A") : ((sym "B") : empty)) (label "finite-recursion"))
   '(r:even ((sym "A") : ((sym "B") : empty)) (label "mutual-recursion"))
   '(∃ (x:outer)
       ((r:eq x:outer (sym "outer") (label "outer-value")) ∧
        (r:shadow (sym "not-outer") x:outer (label "shadow-entry")) (label "outer-bind"))
       (label "outer-fresh"))
   '(∃ (x:outer)
       (suspend (r:shadow (sym "not-outer") x:outer (label "fresh-after-delay"))
                (label "outer-delay")) (label "outer-fresh"))
   '(∃ (x:q)
       (((suspend (suspend (r:eq x:q (sym "A") (label "A")) (label "A-inner")) (label "A-outer")) ∨
         ((suspend (r:eq x:q (sym "B") (label "B")) (label "B-delay")) ∨
          (suspend (r:eq x:q (sym "C") (label "C")) (label "C-delay")) (label "inner-choice"))
         (label "outer-choice")) ∧
        (suspend (r:eq x:q (sym "B") (label "filter")) (label "filter-delay"))
        (label "pending-bind")) (label "query-fresh"))))

(module+ test
  (for* ([goal (in-list finite-goals)] [sparse? (in-list '(#f #t))])
    (test-case (format "full Big finite certificates, native stages, and boundaries sparse=~a: ~s" sparse? goal)
      (define initial
        (s-rel-query-initial goal #:relations definitions
                             #:owners (if sparse?
                                          '(Owners (Owner (u:9 u:2) (label "sparse"))
                                                   (Owner () (label "unused"))) '(Owners))))
      (check-finite-boundaries (check-program initial))))

  (test-case "call premise is eager and retains its environment without implicit Delay"
    (define initial (s-rel-query-initial '(r:eq (sym "A") (sym "A") (label "entry"))
                                         #:relations definitions))
    (match-define (list result labels) (evaluate-full/s initial))
    (check-equal? labels '("eval-call" "eval-atom" "commit-one"))
    (define proof (certify/raw raw-derivations-full/s initial))
    (match-define (list observe-proof) (BigCertificate-premises proof))
    (match-define (list call-proof commit-proof) (BigCertificate-premises observe-proof))
    (match-define (list body-proof) (BigCertificate-premises call-proof))
    (check-equal? (BigCertificate-labels body-proof) '("eval-atom"))
    (check-equal? (BigCertificate-input body-proof)
                  `(program ,definitions
                            (eval (Owners) ((sym "A") =? (sym "A") (label "eq-body"))
                                  (state () () () (label "initial")))))
    (check-equal? (BigCertificate-labels commit-proof) '("commit-one"))
    (check-true (s-rel-observation? result)))

  (test-case "productive recursive program has finite proofs for each public round"
    (define initial
      (s-rel-query-initial '(∃ (x:q) (r:repeat x:q (label "query")) (label "fresh"))
                           #:relations definitions))
    (define (rounds frontier remaining)
      (check-false (s-rel-observation? frontier))
      (check-equal? (check-program frontier) frontier)
      (unless (zero? remaining)
        (rounds (check-program (advance-query frontier)) (sub1 remaining))))
    ;; No full collection or proof search is requested for this infinite stream.
    (rounds (check-program initial) 3))

  (test-case "unguarded recursive operand remains bounded source work before commitment"
    (define initial
      (s-rel-query-initial '((succeed (label "candidate")) ∨
                            (r:loop (label "unproductive")) (label "strict-choice"))
                           #:relations definitions))
    (for ([row (in-list rows)] [input (in-list (list initial (Q-SE initial) (Q-SN initial)))])
      (match-define (list _ relation _ _ _ _) row)
      (define (bounded current remaining [labels '()])
        (cond
          [(zero? remaining) (reverse labels)]
          [else
           (match-define (list (list label next))
             (apply-reduction-relation/tag-with-names relation current))
           (bounded next (sub1 remaining) (cons label labels))]))
      (check-equal? (bounded input 16)
                    (append '("eval-disj" "eval-atom") (make-list 14 "eval-call"))))))
