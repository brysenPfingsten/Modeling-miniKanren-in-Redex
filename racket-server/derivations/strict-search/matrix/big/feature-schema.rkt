#lang racket

(require (for-syntax racket/base racket/list syntax/parse))
(provide feature-specialize)

;; The source feature grammars distinguish exactly these control families.
;; Filter literal judgment and fixed-point match clauses during expansion;
;; there is no runtime feature switch or disabled rule in a smaller instance.
(begin-for-syntax
  (define (disabled feature)
    (define choice '(Yield Emit mplus ∨ "eval-disj" "mplus-empty" "mplus-one"
                         "mplus-yield" "bind-yield" "render-yield" "commit-yield"
                         "advance-emit" "collect-emit"))
    (define delay '(Delay force Forced suspend "eval-suspend" "bind-delay"
                         "force-delay" "render-delay" "commit-delay"
                         "advance-delay" "advance-forced" "collect-delay" "collect-forced"))
    (case feature
      [(core) (append choice delay '("mplus-delay"))]
      [(delay) (append choice '("mplus-delay"))]
      [(disjunction) (append delay '("mplus-delay"))]
      [(search) '()]
      [else (raise-argument-error 'feature-specialize "strict feature" feature)]))
  (define (contains-disabled? tree symbols)
    (cond
      ;; Yield belongs to disjunction; unary More is admitted with Delay.
      ;; Their distinct names need no arity-specific exception here.
      [(pair? tree) (or (contains-disabled? (car tree) symbols)
                        (contains-disabled? (cdr tree) symbols))]
      [else (and (member tree symbols) #t)]))
  (define (specialize syntax symbols omitted)
    (define pieces (syntax->list syntax))
    (cond
      [(not pieces) syntax]
      [else
       (define selected
         (match-head pieces symbols omitted))
       (datum->syntax syntax
                      (map (lambda (piece) (specialize piece symbols omitted)) selected)
                      syntax syntax)]))
  (define (match-head pieces symbols omitted)
    (define (enabled? clause)
      (not (contains-disabled? (syntax->datum clause) symbols)))
    (cond
      [(and (pair? pieces) (eq? (syntax-e (car pieces)) 'define)
            (member 'mplus symbols)
            (syntax->list (second pieces))
            (regexp-match? #rx"^promote-merge"
                           (symbol->string (syntax-e (car (syntax->list (second pieces)))))))
       (list (datum->syntax (car pieces) 'begin))]
      [(and (pair? pieces) (eq? (syntax-e (car pieces)) 'define-judgment-form))
       (define clauses (filter enabled? (drop pieces 6)))
       (if (null? clauses)
           (list (datum->syntax (car pieces) 'begin))
           (append (take pieces 6) clauses))]
      [(and (pair? pieces) (eq? (syntax-e (car pieces)) 'provide))
       (filter (lambda (piece) (not (member (syntax-e piece) omitted))) pieces)]
      [(and (pair? pieces) (eq? (syntax-e (car pieces)) 'match))
       (append (take pieces 2) (filter enabled? (drop pieces 2)))]
      [else pieces])))

(define-syntax (feature-specialize stx)
  (syntax-parse stx
    [(_ feature:id form ...)
     (define symbols (disabled (syntax-e #'feature)))
     (define forms (syntax->list #'(form ...)))
     (define omitted
       (for/list ([form (in-list forms)]
                  #:do [(define pieces (syntax->list form))]
                  #:when (and pieces (pair? pieces)
                              (eq? (syntax-e (car pieces)) 'define-judgment-form)
                              (andmap (lambda (clause)
                                        (contains-disabled? (syntax->datum clause) symbols))
                                      (drop pieces 6))))
         (syntax-e (car (syntax->list (list-ref pieces 3))))))
     #`(begin #,@(map (lambda (form) (specialize form symbols omitted)) forms))]))
