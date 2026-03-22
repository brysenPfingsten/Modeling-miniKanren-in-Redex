#lang racket

(require redex/reduction-semantics)

(provide count-bounced
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
     (and (equal? c scope)
          (subset? (lvars-in sub) scope)
          (subset? (lvars-in dis) scope)
          (subset? (lvars-in trail) scope))]
    [_ #f]))

(define (frontier-exact-scope? f [scope '()])
  (match f
    ['(empty-tree) #t]
    [`(Bounced + ,rest)
     (frontier-exact-scope? rest scope)]
    [`((⊤ ,st) + ,rest)
     (and (state-exact-scope? st scope)
          (frontier-exact-scope? rest scope))]
    [`(Freshened ,intro ,inner)
     (and (distinct? intro)
          (for/and ([u (in-list intro)])
            (not (member? u scope)))
          (frontier-exact-scope? inner (append intro scope)))]
    [`(⊤ ,st)
     (state-exact-scope? st scope)]
    [`(,g ,st)
     (and (state-exact-scope? st scope)
          (subset? (lvars-in g) scope))]
    [`(,inner × ,g ,c)
     (and (equal? c scope)
          (subset? (lvars-in g) scope)
          (frontier-exact-scope? inner scope))]
    [`(delay ,inner)
     (frontier-exact-scope? inner scope)]
    [`(,left <-+ ,right)
     (and (frontier-exact-scope? left scope)
          (frontier-exact-scope? right scope))]
    [`(,left +-> ,right)
     (and (frontier-exact-scope? left scope)
          (frontier-exact-scope? right scope))]
    [_ #f]))

(define (config-exact-scope? cfg)
  (cond
    [(frontier-exact-scope? cfg) #t]
    [else
     (match cfg
       [`(,_gamma ,f)
        (frontier-exact-scope? f)]
       [_ #f])]))

(define (count-bounced datum)
  (match datum
    ['() 0]
    [`(,_gamma ,f)
     (count-bounced f)]
    [`(Bounced + ,rest)
     (add1 (count-bounced rest))]
    [`((⊤ ,_) + ,rest)
     (count-bounced rest)]
    [`(Freshened ,_ ,inner)
     (count-bounced inner)]
    [`(,inner × ,_ ,_)
     (count-bounced inner)]
    [`(delay ,inner)
     (count-bounced inner)]
    [`(,left <-+ ,right)
     (+ (count-bounced left)
        (count-bounced right))]
    [`(,left +-> ,right)
     (+ (count-bounced left)
        (count-bounced right))]
    [_ 0]))

(define (count-freshened datum)
  (match datum
    ['() 0]
    [`(,_gamma ,f)
     (count-freshened f)]
    [`(Freshened ,_ ,inner)
     (add1 (count-freshened inner))]
    [`((⊤ ,_) + ,rest)
     (count-freshened rest)]
    [`(Bounced + ,rest)
     (count-freshened rest)]
    [`(,inner × ,_ ,_)
     (count-freshened inner)]
    [`(delay ,inner)
     (count-freshened inner)]
    [`(,left <-+ ,right)
     (+ (count-freshened left)
        (count-freshened right))]
    [`(,left +-> ,right)
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
