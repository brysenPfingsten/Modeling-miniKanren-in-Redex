#lang racket

(require redex/reduction-semantics
         "../src/core-definitions.rkt"
         "../src/wf-core.rkt"
         "../src/extensions/variant-languages.rkt")

(provide final-config?
         trace-stop-config?
         wf-config-term?
         progress?
         unique-decomposition?
         states-wf?
         shape-closed/L1?
         shape-closed/L2?
         shape-closed/L3?
         shape-closed/L4?
         symbols-in
         tree-of
         sigma-a
         sigma-b
         cfg-call
         cfg-disj
         cfg-flip
         cfg-rail)

(define (final-config? cfg)
  (redex-match? Core end-config cfg))

;; Trace harnesses should only classify true semantic finals as `value`.
;; This keeps regressions visible (instead of masking non-final stuck states).
(define (trace-stop-config? cfg)
  (final-config? cfg))

(define (wf-config-term? cfg)
  (judgment-holds (wf-config? ,cfg)))

(define (progress? rel cfg)
  (or (final-config? cfg)
      (not (null? (apply-reduction-relation rel cfg)))))

(define (unique-decomposition? rel cfg)
  (define next* (apply-reduction-relation rel cfg))
  (if (final-config? cfg)
      (null? next*)
      (= (length next*) 1)))

(define (states-in datum [acc '()])
  (match datum
    [`(state ,_sub ,_c ,_trail ,_tag) (cons datum acc)]
    ['() acc]
    [(cons a d) (states-in a (states-in d acc))]
    [_ acc]))

(define (states-wf? cfg)
  (for/and ([st (in-list (states-in cfg))])
    (judgment-holds (wf-state? ,st))))

(define (shape-closed? lang-id rel cfg)
  (define cfg-in-lang?
    (case lang-id
      [(L1) (lambda (cfg^) (redex-match? L1 config cfg^))]
      [(L2) (lambda (cfg^) (redex-match? L2 config cfg^))]
      [(L3) (lambda (cfg^) (redex-match? L3 config cfg^))]
      [(L4) (lambda (cfg^) (redex-match? L4 config cfg^))]
      [else (lambda (_cfg^) #f)]))
  (for/and ([cfg^ (in-list (apply-reduction-relation rel cfg))])
    (cfg-in-lang? cfg^)))

(define (shape-closed/L1? rel cfg)
  (shape-closed? 'L1 rel cfg))

(define (shape-closed/L2? rel cfg)
  (shape-closed? 'L2 rel cfg))

(define (shape-closed/L3? rel cfg)
  (shape-closed? 'L3 rel cfg))

(define (shape-closed/L4? rel cfg)
  (shape-closed? 'L4 rel cfg))

(define (symbols-in d)
  (match d
    ['() '()]
    [(? symbol?) (list d)]
    [(cons a b) (append (symbols-in a) (symbols-in b))]
    [_ '()]))

(define (tree-of cfg)
  (second cfg))

(define sigma-a
  (term (state () () () (label "a"))))

(define sigma-b
  (term (state () () () (label "b"))))

(define cfg-call
  (term (((r:id (x:0) (x:0 =? (sym "ok") (label "eq"))))
         ((r:id (sym "ok") (label "call"))
          (state () () () (label "s"))))))

(define cfg-disj
  (term (() ((⊤ (state () () () (label "a")))
             <-+
             (⊤ (state () () () (label "b")))))))

(define cfg-flip
  (term (() ((delay (empty-tree))
             <-+
             (⊤ (state () () () (label "b")))))))

(define cfg-rail
  (term (() ((delay (empty-tree))
             <-+
             (⊤ (state () () () (label "b")))))))
