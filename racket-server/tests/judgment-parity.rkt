#lang racket

(require rackunit
         rackunit/text-ui
         redex/reduction-semantics
         (only-in "../src/definitions.rkt" L)
         (only-in "../src/core-definitions.rkt" Core)
         "../src/transpiler.rkt"
         "../src/syntax-checking.rkt"
         "../src/judgment-forms.rkt"
         "../src/core-judgment-forms.rkt"
         "../src/legacy-variant-adapter.rkt")

(provide JUDGMENT-PARITY)

(define JP-SEED 20260302)
(define JP-RANDOM-SAMPLES 120)

(define JP-RNG (make-pseudo-random-generator))
(parameterize ([current-pseudo-random-generator JP-RNG])
  (random-seed JP-SEED))
(define (jprandom n)
  (parameterize ([current-pseudo-random-generator JP-RNG])
    (random n)))

(struct parity-row (label source legacy canonical legacy-ok? canonical-ok? class)
  #:transparent)

(define (source->forms src)
  (let loop ([port (open-input-string src)] [acc '()])
    (define expr (read port))
    (if (eof-object? expr)
        (reverse acc)
        (loop port (cons expr acc)))))

(define (forms->source forms)
  (string-join (map ~s forms) "\n\n"))

(define (classify legacy-ok? canonical-ok?)
  (cond
    [(and legacy-ok? canonical-ok?) 'TT]
    [(and legacy-ok? (not canonical-ok?)) 'TF]
    [(and (not legacy-ok?) canonical-ok?) 'FT]
    [else 'FF]))

(define (analyze-source label src)
  (check-syntax-capture-error src)
  (define forms (source->forms src))
  (define-values (legacy _html) (parse-prog forms))
  (define canonical (legacy-program->canonical-config legacy))
  (define legacy-in-domain? (redex-match? L p legacy))
  (define canonical-in-domain? (redex-match? Core config canonical))
  (define legacy-ok? (and legacy-in-domain? (judgment-holds (closed-program? ,legacy))))
  (define canonical-ok? (and canonical-in-domain? (judgment-holds (wf-config? ,canonical))))
  (define class
    (cond
      [(not legacy-in-domain?) 'L-OD]
      [(not canonical-in-domain?) 'C-OD]
      [else (classify legacy-ok? canonical-ok?)]))
  (parity-row label
              src
              legacy
              canonical
              legacy-ok?
              canonical-ok?
              class))

(define frontend-fixed-sources
  (list
   (cons "core-eq"
         "(run* (q)
            (== q 'cat))")
   (cons "core-fresh+conj"
         "(run* (q)
            (fresh (x)
              (== x 'dog)
              (== q x)))")
   (cons "core-two-defrels-no-calls"
         "(defrel (left x) (== x 'cat))
          (defrel (right y) (== y 'dog))
          (run* (q) (== q 'cat))")
   (cons "core-list-term"
         "(run* (q)
            (== q (cons 'cat (cons 'dog '()))))")
   (cons "core-nested-fresh"
         "(run* (q)
            (fresh (x)
              (fresh (y)
                (== x 'owl)
                (== y x)
                (== q y))))")))

(define targeted-sources
  '())

(define symbols-pool '(cat dog fish turtle owl fox ant bee elk yak))

(define (random-const)
  (list 'quote (list-ref symbols-pool (jprandom (length symbols-pool)))))

(define (gen-random-program i)
  (define x (string->symbol (format "x~a" i)))
  (define y (string->symbol (format "y~a" i)))
  (define q (string->symbol (format "q~a" i)))
  (define c1 (random-const))
  (define c2 (random-const))
  (define def-goal
    (case (jprandom 3)
      [(0) `(== ,x ,c1)]
      [(1) `(fresh (,y) (== ,x ,y) (== ,y ,c1))]
      [else `(fresh (,y) (== ,x ,c1) (== ,y ,c2) (== ,x ,y))]))
  (define forms
    (list `(run* (,q) (fresh (,x) ,def-goal (== ,q ,x)))))
  (forms->source forms))

(define (build-random-sources n)
  (for/list ([i (in-range n)])
    (cons (format "random-~a" i)
          (gen-random-program i))))

(define (count-by rows class-sym)
  (for/sum ([r (in-list rows)])
    (if (eq? class-sym (parity-row-class r)) 1 0)))

(define (mismatch-report rows)
  (string-join
   (for/list ([r (in-list rows)])
     (format "~a class=~a\nsource:\n~a\nlegacy:\n~s\ncanonical:\n~s\n"
             (parity-row-label r)
             (parity-row-class r)
             (parity-row-source r)
             (parity-row-legacy r)
             (parity-row-canonical r)))
   "\n---\n"))

(define-test-suite JUDGMENT-PARITY
  (test-case "legacy closed-program? and canonical wf-config? parity"
    (define tier-a frontend-fixed-sources)
    (define tier-c targeted-sources)
    (define tier-b (build-random-sources JP-RANDOM-SAMPLES))
    (define all-sources (append tier-a tier-c tier-b))
    (define rows
      (for/list ([entry (in-list all-sources)])
        (match-define (cons label src) entry)
        (analyze-source label src)))

    (define tt (count-by rows 'TT))
    (define tf (count-by rows 'TF))
    (define ft (count-by rows 'FT))
    (define ff (count-by rows 'FF))
    (define l-od (count-by rows 'L-OD))
    (define c-od (count-by rows 'C-OD))

    (printf "[judgment-parity] samples=~a fixed=~a targeted=~a random=~a seed=~a classes(TT/TF/FT/FF/L-OD/C-OD)=~a/~a/~a/~a/~a/~a\n"
            (length rows)
            (length tier-a)
            (length tier-c)
            (length tier-b)
            JP-SEED
            tt tf ft ff l-od c-od)

    (check-true (> (length rows) 0) "expected at least one analyzed sample")
    (check-true (> tt 0) "expected at least one jointly accepted sample (TT)")
    (check-equal? l-od 0 "unexpected legacy domain misses in parity corpus")
    (check-equal? c-od 0 "unexpected canonical domain misses in parity corpus")

    (define mismatches
      (filter (lambda (r) (memq (parity-row-class r) '(TF FT))) rows))
    (check-equal?
     (length mismatches)
     0
     (string-append
      "found legacy/canonical judgment disagreements\n"
      (mismatch-report mismatches)))))

(module+ test
  (run-tests JUDGMENT-PARITY))
