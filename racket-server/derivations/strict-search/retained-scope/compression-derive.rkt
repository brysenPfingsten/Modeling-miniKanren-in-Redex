#lang racket

(require racket/runtime-path
         (prefix-in checkpoint: "derive.rkt")
         (only-in "register-derive.rkt" register-module-text))
(provide compress-control-definitions compressed-control-definitions
         generated-text generate! check-generated!)
(define-runtime-path directory ".")

;; The sole compression is justified by this exact source site: both handlers
;; have the same owners and continuation, and outcome/d dispatches immediately
;; to one of them. Keep native atomic/data evaluation at its original position.
;; Do not dispatch return/d here: it may enter bind, merge, or commitment.
(define atomic-arm
  '[atom
    (define outcome (atomic/data atom state))
    (outcome/d outcome (FEmpty owners k) (SOne owners k))])
(define compressed-atomic-arm
  '[atom
    (define outcome (atomic/data atom state))
    (match outcome
      [(Failure) (return/d `(Empty ,owners) k)]
      [(Success result-state) (return/d `(One ,owners ,result-state) k)])])

;; These exact clauses are the evidence for the three-edge atomic span. If the
;; checkpoint changes their behavior, generation must fail for another audit.
(define eliminated-definitions
  '((define (outcome/d outcome failure success)
      (match outcome
        [(Failure) (failure/d failure)]
        [(Success state) (success/d success state)]))
    (define (failure/d failure)
      (match failure [(FEmpty owners k) (return/d `(Empty ,owners) k)]))
    (define (success/d success state)
      (match success [(SOne owners k) (return/d `(One ,owners ,state) k)]))))
(define eliminated-names '(outcome/d failure/d success/d))

(define (mentions-eliminated? datum)
  (match datum
    [(cons first rest)
     (or (mentions-eliminated? first) (mentions-eliminated? rest))]
    [_ (and (member datum eliminated-names) #t)]))

(define (compress-control-definitions definitions)
  (define signatures (checkpoint:control-signatures definitions))
  (define names (map car signatures))
  (unless (and (= (length names) 13)
               (= (length names) (length (remove-duplicates names))))
    (error 'compress-control-definitions "expected thirteen unique checkpoint controls"))
  (for ([expected (in-list eliminated-definitions)])
    (unless (member expected definitions)
      (error 'compress-control-definitions
             "atomic handler definition changed; compression needs review: ~e" expected)))
  (define compressed
    (for/list ([definition (in-list definitions)]
               #:unless (member definition eliminated-definitions))
      (match definition
        [`(define (eval/d goal state owners inherited k)
            (define relations (goal-relations goal))
            (match (goal-body goal) ,clauses ...))
         (unless (and (pair? clauses)
                      (equal? (last clauses) atomic-arm)
                      (= 1 (count (lambda (clause) (equal? clause atomic-arm)) clauses)))
           (error 'compress-control-definitions
                  "eval/d atomic site changed; compression needs review"))
         `(define (eval/d goal state owners inherited k)
            (define relations (goal-relations goal))
            (match (goal-body goal) ,@(drop-right clauses 1) ,compressed-atomic-arm))]
        [`(define (eval/d ,_ ...) ,_ ...)
         (error 'compress-control-definitions "eval/d shape changed; compression needs review")]
        [_ definition])))
  (unless (and (= (length compressed) 10)
               (member 'eval/d names)
               (not (mentions-eliminated? compressed)))
    (error 'compress-control-definitions
           "expected ten controls with no remaining outcome-handler transfers"))
  compressed)

(define (compressed-control-definitions)
  (compress-control-definitions (checkpoint:control-definitions)))

(define (generated-text)
  (register-module-text
   (compressed-control-definitions)
   "defunc.rkt via the checked atomic-handler compression in compression-derive.rkt"))

(define (generate!)
  (call-with-output-file (build-path directory "compressed.rkt")
    (lambda (output) (display (generated-text) output))
    #:exists 'truncate/replace))

(define (check-generated!)
  (unless (equal? (generated-text) (file->string (build-path directory "compressed.rkt")))
    (error 'check-generated! "compressed.rkt is stale; run compression-derive.rkt"))
  #t)

(module+ main
  (match (vector->list (current-command-line-arguments))
    ['() (generate!) (displayln "Generated compressed.rkt with local atomic-handler compression.")]
    ['("--check") (check-generated!) (displayln "Compressed artifact matches the checked source transformation.")]
    [_ (error 'compression-derive "usage: racket compression-derive.rkt [--check]")]))
