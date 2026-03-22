#lang racket

(require redex/reduction-semantics)

(provide count-bounced
         count-answers
         count-freshened
         frontier-exact-scope?
         config-exact-scope?
         trace-deterministic)

(define u-rx #px"^u:")

(define (logic-var-symbol? v)
  (and (symbol? v)
       (regexp-match? u-rx (symbol->string v))))

(define (member? x xs)
  (and (member x xs) #t))

(define (distinct? xs)
  (= (length xs)
     (length (remove-duplicates xs))))

(define (subset? xs ys)
  (for/and ([x (in-list xs)])
    (member? x ys)))

(define (same-members? xs ys)
  (and (subset? xs ys)
       (subset? ys xs)))

(define (lvars-in datum [acc '()])
  (match datum
    ['() acc]
    [(? logic-var-symbol? u)
     (if (member? u acc)
         acc
         (cons u acc))]
    [(cons a d)
     (lvars-in a (lvars-in d acc))]
    [_ acc]))

(define (state-exact-scope? st scope)
  (match st
    [`(state ,sub ,dis ,c ,trail ,_tag)
     (and (same-members? c scope)
          (subset? (lvars-in sub) scope)
          (subset? (lvars-in dis) scope)
          (subset? (lvars-in trail) scope))]
    [_ #f]))

(define (frontier-exact-scope? f [scope '()])
  (match f
    ['(empty-tree) #t]
    ['Bounced #t]
    [(list 'Bounced '+ rest)
     (frontier-exact-scope? rest scope)]
    [(list (list '⊤ st) '+ rest)
     (and (state-exact-scope? st scope)
          (frontier-exact-scope? rest scope))]
    [(list prefix '+ rest)
     (and (frontier-exact-scope? prefix scope)
          (frontier-exact-scope? rest scope))]
    [(list 'Freshened intro inner)
     (and (distinct? intro)
          (for/and ([u (in-list intro)])
            (not (member? u scope)))
          (frontier-exact-scope? inner (append intro scope)))]
    [(list '⊤ st)
     (state-exact-scope? st scope)]
    [(list g st)
     (and (state-exact-scope? st scope)
          (subset? (lvars-in g) scope))]
    [(list inner '× g c)
     (and (same-members? c scope)
          (subset? (lvars-in g) scope)
          (frontier-exact-scope? inner scope))]
    [(list 'delay inner)
     (frontier-exact-scope? inner scope)]
    [(list left '<-+ right)
     (and (frontier-exact-scope? left scope)
          (frontier-exact-scope? right scope))]
    [(list left '+-> right)
     (and (frontier-exact-scope? left scope)
          (frontier-exact-scope? right scope))]
    [_ #f]))

(define (config-exact-scope? cfg)
  (cond
    [(frontier-exact-scope? cfg) #t]
    [else
     (match cfg
       [(list gamma f) #:when (list? gamma)
        (frontier-exact-scope? f)]
       [_ #f])]))

(define (count-bounced datum)
  (match datum
    ['() 0]
    [(list gamma f) #:when (list? gamma)
     (count-bounced f)]
    ['Bounced 1]
    [(list 'Bounced '+ rest)
     (add1 (count-bounced rest))]
    [(list (list '⊤ _) '+ rest)
     (count-bounced rest)]
    [(list prefix '+ rest)
     (+ (count-bounced prefix)
        (count-bounced rest))]
    [(list 'Freshened _ inner)
     (count-bounced inner)]
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
    [(list (list '⊤ _) '+ rest)
     (add1 (count-answers rest))]
    [(list prefix '+ rest)
     (+ (count-answers prefix)
        (count-answers rest))]
    [(list 'Freshened _ inner)
     (count-answers inner)]
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
    [(list 'Freshened _ inner)
     (add1 (count-freshened inner))]
    [(list (list '⊤ _) '+ rest)
     (count-freshened rest)]
    [(list 'Bounced '+ rest)
     (count-freshened rest)]
    [(list prefix '+ rest)
     (+ (count-freshened prefix)
        (count-freshened rest))]
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

(define (trace-deterministic rel cfg [step-cap 64] [i 0] [acc '()])
  (define next* (apply-reduction-relation/tag-with-names rel cfg))
  (match next*
    ['()
     (values (reverse acc) cfg 'done)]
    [(list _ ...) #:when (>= i step-cap)
     (values (reverse acc) cfg 'cap)]
    [(list (list name cfg1))
     (trace-deterministic rel
                          cfg1
                          step-cap
                          (add1 i)
                          (cons (~a name) acc))]
    [_ (values (reverse acc) cfg 'nondeterministic)]))
