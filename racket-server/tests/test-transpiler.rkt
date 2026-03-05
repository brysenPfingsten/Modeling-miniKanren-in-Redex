#lang racket
(require rackunit
         rackunit/text-ui
         redex/reduction-semantics
         (prefix-in l4: "../src/extensions/l4-railroad-syntax.rkt")
         (prefix-in j: "../src/variant-judgment-forms.rkt")
         "../src/definitions.rkt"
         "../src/transpiler.rkt")

(define-test-suite ASSOCIATIVITY
  (test-case "Conjunctions Left Associate"
    (define PROG '((run* (q) (== 1 1) (== 2 2) (== 3 3))))
    (define-values (PARSED _) (parse-prog PROG))
    (check-true (redex-match? L (((_ _ ((g_1 ∧ g_2 _) ∧ g_3 _) _) _) Γ) PARSED)))

  (test-case "Disjunctions Right Associate"
    (define PROG '((run* (q)
                    (conde
                      [(conde
                        [(same q 'turtle)]
                        [(same q 'cat)]
                        [(== q 'dog)])]
                      [(same q 'fish)]))))
    (define-values (PARSED _) (parse-prog PROG))
    (check-true (redex-match? L (((_ _ ((g_1 ∨ (g_2 ∨ g_3 _) _) ∨ g_4 _) _) σ) Γ) PARSED))

    (define PROG1 '((run* (q)
                      (conde
                        ((conde
                          ((same q 'turtle))
	                      ((conde
	                          ((same q 'cat))
	                          ((== q 'dog))))))
                            ((same q 'fish))))))
    (define-values (PARSED1 _1) (parse-prog PROG1))
    (check-true (redex-match? L (((_ _ ((g_1 ∨ (g_2 ∨ g_3 _) _) ∨ g_4 _) _) σ) Γ) PARSED1))

    (define PROG2 '((run* (q)
                    (conde
                      [(same q 'turtle)]
                      [(same q 'cat)]
                      [(== q 'dog)]
                      [(same q 'fish)]))))
    (define-values (PARSED2 _2) (parse-prog PROG2))
    (check-true (redex-match? L (((_ _ (g_1 ∨ (g_2 ∨ (g_3 ∨ g_4 _) _) _) _) σ) Γ) PARSED2))
    ))

(define (read-all port)
  (let ([expr (read port)])
    (if (eof-object? expr)
        '()
        (cons expr (read-all port)))))

(define (parse-src src)
  (parse-prog (read-all (open-input-string src))))

(define (parse-src/canonical src)
  (parse-prog/canonical (read-all (open-input-string src))))

(define-test-suite CANONICAL-TRANSLATION
  (test-case
   "run*-only canonical translation is L4/config and wf"
   (define-values (cfg html)
     (parse-src/canonical "(run* (q) (== 'a 'a))"))
   (check-true (redex-match? l4:L4 config cfg))
   (check-true (j:wf-config/target? "L4/config" cfg))
   (check-true (string? html)))

  (test-case
   "defrel+run* canonical translation is L4/config and wf"
   (define-values (cfg html)
     (parse-src/canonical
      "(defrel (same x y) (== x y))
(run* (q) (same q 'cat))"))
   (check-true (redex-match? l4:L4 config cfg))
   (check-true (j:wf-config/target? "L4/config" cfg))
   (check-true (string? html)))

  (test-case
   "relation-call arity mismatch parses but is rejected by wf"
   (define-values (cfg _html)
     (parse-src/canonical
      "(defrel (same x y) (== x y))
(run* (q) (same q))"))
   (check-true (redex-match? l4:L4 config cfg))
   (check-false (j:wf-config/target? "L4/config" cfg)))

  (test-case
   "legacy parse-prog surface translation still shape-checks in legacy language"
   (define-values (model html)
     (parse-src
      "(defrel (same x y) (== x y))
(run* (q) (same q 'cat))"))
   (check-true (redex-match? L p model))
   (check-true (string? html))))

(define/provide-test-suite TRANSPILER
  #:after (thunk (displayln "Finished running tests for transpiler."))

  ASSOCIATIVITY
  CANONICAL-TRANSLATION)

#;(run-tests TRANSPILER)
