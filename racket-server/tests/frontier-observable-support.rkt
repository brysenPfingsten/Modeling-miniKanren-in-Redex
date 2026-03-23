#lang racket

(require redex/reduction-semantics)

(provide count-bounced
         count-answers
         count-freshened
         state-c-agrees-with-scope?
         core-c-scope-agreement?
         config-c-scope-agreement?
         core-exact-scope?
         config-exact-scope?
         trace-deterministic)

(define u-rx #px"^u:")

(define (logic-var-symbol? v)
  (and (symbol? v)
       (regexp-match? u-rx (symbol->string v))))

(define (distinct? xs)
  (= (length xs)
     (length (remove-duplicates xs))))

(define (subset? xs ys)
  (for/and ([x (in-list xs)])
    (and (member x ys) #t)))

(define (lvars-in datum [acc '()])
  (match datum
    ['() acc]
    [(? logic-var-symbol? u)
     (if (member u acc)
         acc
         (cons u acc))]
    [(cons a d)
     (lvars-in a (lvars-in d acc))]
    [_ acc]))

(define (state-c-agrees-with-scope? st scope)
  (match st
    [`(state ,sub ,dis ,c ,trail ,_tag)
     (equal? c scope)]
    [_ #f]))

(define (state-lvars-contained? st scope)
  (match st
    [`(state ,sub ,dis ,_ ,trail ,_tag)
     (and (subset? (lvars-in sub) scope)
          (subset? (lvars-in dis) scope)
          (subset? (lvars-in trail) scope))]
    [_ #f]))

(define (core-c-scope-agreement? f [scope '()])
  (match f
    ['(empty-tree) #t]
    [(list 'Freshened intro _tag inner)
     (and (distinct? intro)
          (for/and ([u (in-list intro)])
            (not (member u scope)))
          (core-c-scope-agreement? inner (append intro scope)))]
    [(list 'Bounced '+ rest)
     (core-c-scope-agreement? rest scope)]
    [(list (list 'Freshened intro _tag inner) '+ rest)
     (and (distinct? intro)
          (for/and ([u (in-list intro)])
            (not (member u scope)))
          (core-c-scope-agreement? inner (append intro scope))
          (core-c-scope-agreement? rest scope))]
    [(list (list '⊤ st) '+ rest)
     (and (state-c-agrees-with-scope? st scope)
          (core-c-scope-agreement? rest scope))]
    [(list '⊤ st)
     (state-c-agrees-with-scope? st scope)]
    [(list _ st)
     (state-c-agrees-with-scope? st scope)]
    [(list inner '× _ c)
     (and (equal? c scope)
          (core-c-scope-agreement? inner scope))]
    [(list 'delay inner)
     (core-c-scope-agreement? inner scope)]
    [(list left '<-+ right)
     (and (core-c-scope-agreement? left scope)
          (core-c-scope-agreement? right scope))]
    [(list left '+-> right)
     (and (core-c-scope-agreement? left scope)
          (core-c-scope-agreement? right scope))]
    [_ #f]))

(define (core-lvars-contained? f [scope '()])
  (match f
    ['(empty-tree) #t]
    [(list 'Freshened intro _tag inner)
     (and (distinct? intro)
          (for/and ([u (in-list intro)])
            (not (member u scope)))
          (core-lvars-contained? inner (append intro scope)))]
    [(list 'Bounced '+ rest)
     (core-lvars-contained? rest scope)]
    [(list (list 'Freshened intro _tag inner) '+ rest)
     (and (distinct? intro)
          (for/and ([u (in-list intro)])
            (not (member u scope)))
          (core-lvars-contained? inner (append intro scope))
          (core-lvars-contained? rest scope))]
    [(list (list '⊤ st) '+ rest)
     (and (state-lvars-contained? st scope)
          (core-lvars-contained? rest scope))]
    [(list '⊤ st)
     (state-lvars-contained? st scope)]
    [(list g st)
     (and (state-lvars-contained? st scope)
          (subset? (lvars-in g) scope))]
    [(list inner '× g c)
     (and (equal? c scope)
          (subset? (lvars-in g) scope)
          (core-lvars-contained? inner scope))]
    [(list 'delay inner)
     (core-lvars-contained? inner scope)]
    [(list left '<-+ right)
     (and (core-lvars-contained? left scope)
          (core-lvars-contained? right scope))]
    [(list left '+-> right)
     (and (core-lvars-contained? left scope)
          (core-lvars-contained? right scope))]
    [_ #f]))

(define (core-exact-scope? f [scope '()])
  (and (core-c-scope-agreement? f scope)
       (core-lvars-contained? f scope)))

(define (config-c-scope-agreement? cfg)
  (or (core-c-scope-agreement? cfg)
      (match cfg
        [(list gamma f)
         #:when (and (list? gamma)
                     (core-c-scope-agreement? f))
         #t]
        [_ #f])))

(define (config-exact-scope? cfg)
  (or (core-exact-scope? cfg)
      (match cfg
        [(list gamma f)
         #:when (and (list? gamma)
                     (core-exact-scope? f))
         #t]
        [_ #f])))

(define (count-bounced datum)
  (match datum
    ['() 0]
    [(list gamma f) #:when (list? gamma)
     (count-bounced f)]
    [(list 'Freshened _ _ inner)
     (count-bounced inner)]
    [(list 'Bounced '+ rest)
     (add1 (count-bounced rest))]
    [(list (list 'Freshened _ _ inner) '+ rest)
     (+ (count-bounced inner)
        (count-bounced rest))]
    [(list (list '⊤ _) '+ rest)
     (count-bounced rest)]
    [(list inner '× _ _)
     (count-bounced inner)]
    [(list 'delay inner)
     (count-bounced inner)]
    [(list left '<-+ right)
     (+ (count-bounced left)
        (count-bounced right))]
    [(list left '+-> right)
     (+ (count-bounced left)
        (count-bounced right))]
    [_ 0]))

(define (count-answers datum)
  (match datum
    ['() 0]
    [(list gamma f) #:when (list? gamma)
     (count-answers f)]
    [(list 'Freshened _ _ inner)
     (count-answers inner)]
    [(list (list 'Freshened _ _ inner) '+ rest)
     (+ (count-answers inner)
        (count-answers rest))]
    [(list (list '⊤ _) '+ rest)
     (add1 (count-answers rest))]
    [(list 'Bounced '+ rest)
     (count-answers rest)]
    [(list '⊤ _)
     1]
    [(list inner '× _ _)
     (count-answers inner)]
    [(list 'delay inner)
     (count-answers inner)]
    [(list left '<-+ right)
     (+ (count-answers left)
        (count-answers right))]
    [(list left '+-> right)
     (+ (count-answers left)
        (count-answers right))]
    [_ 0]))

(define (count-freshened datum)
  (match datum
    ['() 0]
    [(list gamma f) #:when (list? gamma)
     (count-freshened f)]
    [(list 'Freshened _ _ inner)
     (add1 (count-freshened inner))]
    [(list (list 'Freshened _ _ inner) '+ rest)
     (+ (add1 (count-freshened inner))
        (count-freshened rest))]
    [(list (list '⊤ _) '+ rest)
     (count-freshened rest)]
    [(list 'Bounced '+ rest)
     (count-freshened rest)]
    [(list inner '× _ _)
     (count-freshened inner)]
    [(list 'delay inner)
     (count-freshened inner)]
    [(list left '<-+ right)
     (+ (count-freshened left)
        (count-freshened right))]
    [(list left '+-> right)
     (+ (count-freshened left)
        (count-freshened right))]
    [_ 0]))

(define (trace-deterministic rel cfg [step-cap 64])
  (define next*
    (remove-duplicates
     (apply-reduction-relation/tag-with-names rel cfg)))
  (match next*
    ['()
     (values '() cfg 'done)]
    [_ #:when (zero? step-cap)
       (values '() cfg 'cap)]
    [(list (list name cfg1))
     (define-values (steps cfg^ status)
       (trace-deterministic rel cfg1 (sub1 step-cap)))
     (values (cons (~a name) steps)
             cfg^
             status)]
    [_ (values '() cfg 'nondeterministic)]))
