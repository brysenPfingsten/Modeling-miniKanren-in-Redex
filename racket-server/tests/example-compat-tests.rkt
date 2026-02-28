#lang racket

(require rackunit
         rackunit/text-ui
         redex/reduction-semantics
         "../src/definitions.rkt"
         "../src/judgment-forms.rkt"
         "../src/transpiler.rkt"
         "../src/legacy-variant-adapter.rkt"
         "../src/extensions/l4-railroad-syntax.rkt")

(provide EXAMPLE-COMPAT)

;; Keep these programs aligned with frontend/src/utils/example_programs.js.
(define EXAMPLE-PROGRAMS
  (list
   (cons "appendo"
         "(defrel (appendo l s out)
  (conde
    [(== l '())
    (== s out)]
    [(fresh (a d res)
      (== l (cons a d))
      (== out (cons a res))
      (appendo d s res))]
  ))

(run* (q) (appendo (list 'minikanren) (list 'visualizer) q))")
   (cons "appendoh1"
         "(defrel (appendoh l s out)
  (conde
   [(== l '()) (== s out)]
   [(fresh (a d res)
      (== l (cons a d))
      (== out (cons a res))
      (appendoh d s out))]))

(run* (q) (appendoh '(dog) q '(dog cat)))")
   (cons "appendoh2"
         "(defrel (appendoh l s out)
  (conde
   [(== l '()) (== s out)]
   [(fresh (a d res)
      (appendoh d s res)
      (== l (cons a d))
      (== out (cons a res)))]))

(run* (q r s) (appendoh q r s))")
   (cons "same"
         "(defrel (same x y)
  (== x y))

(run* (q)
  (conde
    [(conde
       [(same q 'turtle)]
       [(same q 'cat)]
       [(== q 'dog)])]
    [(same q 'fish)]))")
   (cons "div3o"
         "(defrel (same-counto bn)
  (conde
   [(== bn `(1 1))]
   [(fresh (a ad dd)
      (== `(,a ,ad . ,dd) bn)
      (conde
       [(== a ad) (same-counto dd)]
       [(== `(,a ,ad) '(1 0)) (mod+1o dd)]
       [(== `(,a ,ad) '(0 1)) (mod+2o dd)]))]))

(defrel (mod+1o bn)
  (conde
   [(== bn `(0 1))]
   [(fresh (a ad dd)
      (== `(,a ,ad . ,dd) bn)
      (conde
       [(== a ad) (mod+1o dd)]
       [(== `(,a ,ad) '(1 0)) (mod+2o dd)]
       [(== `(,a ,ad) '(0 1)) (same-counto dd)]))]))

(defrel (mod+2o bn)
  (conde
   [(== bn '(1))]
   [(fresh (a ad dd)
      (== `(,a ,ad . ,dd) bn)
      (conde
       [(== a ad) (mod+2o dd)]
       [(== `(,a ,ad) '(1 0)) (same-counto dd)]
       [(== `(,a ,ad) '(0 1)) (mod+1o dd)]))]))

(defrel (multiple-of-threeo bn)
  (conde
   [(== bn '())]
   [(same-counto bn)]))

(run* (q) (multiple-of-threeo q))")))

(define (read-all port)
  (let ([expr (read port)])
    (if (eof-object? expr)
        '()
        (cons expr (read-all port)))))

(define (parse-src src)
  (parse-prog (read-all (open-input-string src))))

(define (assert-example-compat! name src)
  (define-values (legacy html) (parse-src src))
  (check-true (string? html) (format "~a should produce html-guid source" name))
  (check-true (redex-match? L p legacy) (format "~a should parse as legacy L program" name))
  (check-true (judgment-holds (closed-program? ,legacy))
              (format "~a should be closed in legacy judgments" name))
  (define lifted (legacy-program->l4-config legacy))
  (check-true (redex-match? L4 config lifted)
              (format "~a should lift into L4 config syntax" name))
  (check-true (l4-config? lifted)
              (format "~a should satisfy adapter L4 predicate" name)))

(define (lookup-example name)
  (define maybe (assoc name EXAMPLE-PROGRAMS))
  (if maybe
      (cdr maybe)
      (error 'lookup-example "missing example ~a" name)))

(define/provide-test-suite EXAMPLE-COMPAT
  (test-case "frontend example appendo parses and lifts to L4"
    (assert-example-compat! "appendo" (lookup-example "appendo")))
  (test-case "frontend example appendoh1 parses and lifts to L4"
    (assert-example-compat! "appendoh1" (lookup-example "appendoh1")))
  (test-case "frontend example appendoh2 parses and lifts to L4"
    (assert-example-compat! "appendoh2" (lookup-example "appendoh2")))
  (test-case "frontend example same parses and lifts to L4"
    (assert-example-compat! "same" (lookup-example "same")))
  (test-case "frontend example div3o parses and lifts to L4"
    (assert-example-compat! "div3o" (lookup-example "div3o"))))

(module+ test
  (run-tests EXAMPLE-COMPAT))
