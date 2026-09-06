#lang racket

(provide transform-tail transform-body)

;; A deliberately restricted tail-call reifier, shared by the functional
;; derivations. It transforms control transfers, not their semantic bodies.
;; Non-tail references to control functions are rejected; direct primitive
;; expressions are preserved. This is not a general Racket compiler.
(define (primitive! expression names)
  (match expression
    [`(quote ,_) (void)]
    [(? symbol? name)
     (when (member name names)
       (error 'derive "control procedure in a non-tail position: ~e" expression))]
    [(cons head tail) (primitive! head names) (primitive! tail names)]
    [_ (void)]))

(define (transform-body body names jump halt)
  (when (null? body) (error 'derive "empty control body"))
  (define preceding (drop-right body 1))
  (for-each (lambda (expression) (primitive! expression names)) preceding)
  (append preceding (list (transform-tail (last body) names jump halt))))

(define (transform-tail expression names jump halt)
  (match expression
    [`(match ,subject ,clauses ...)
     (primitive! subject names)
     `(match ,subject
        ,@(for/list ([clause (in-list clauses)])
            (match-define (cons pattern body) clause)
            `(,pattern ,@(transform-body body names jump halt))))]
    [`(if ,test ,yes ,no)
     (primitive! test names)
     `(if ,test ,(transform-tail yes names jump halt)
                ,(transform-tail no names jump halt))]
    [`(begin ,body ...) `(begin ,@(transform-body body names jump halt))]
    [(list (? (lambda (name) (member name names)) name) arguments ...)
     (for-each (lambda (argument) (primitive! argument names)) arguments)
     (jump name arguments)]
    [_ (primitive! expression names) (halt expression)]))
