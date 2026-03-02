#lang racket
(require redex/reduction-semantics
         json
         racket/hash
         "definitions.rkt"
         "reification.rkt")

(provide to-json
         to-json/canonical
         prog->tree
         num-query-vars
         num-query-vars/canonical)

(define num-of-query-vars 'uninitialized)
(define (set-num-query-vars! n)
  (set! num-of-query-vars n))

(define (extract-name input-str)
  (define re #rx"^[x,r]:([^«]+)") ;; (x or r):letters ; Stops at the <<...>>
  (define matches (regexp-match re input-str))
  (if matches (second matches) input-str))

(define-metafunction L
  list->list : any -> any
  [(list->list empty) ()]
  [(list->list (t_1 : t_2))
   ,(cons (term (term->json t_1))
          (term (list->list t_2)))]
  [(list->list (t)) ,(cons (term (term->json t)) '())]
  [(list->list t) ,(cons (term (term->json t)) '())])

(define-metafunction L
  term->json : t -> any
  [(term->json x) ,(hasheq 'var (extract-name (symbol->string (term x))))]
  [(term->json empty) ()]
  [(term->json (sym string)) ,(hasheq 'sym (term string))]
  [(term->json (nat natural)) ,(hasheq 'num (term natural))]
  [(term->json (t_1 : t_2)) (list->list (t_1 : t_2))]
  [(term->json t) t])

(define (args->json vars)
  (map (λ (v) (term (term->json ,v))) vars))

(define (sub->json sub)
  (map (λ (p) (let ([var (car p)]
                    [val (term (term->json ,(cadr p)))])
                (hasheq 'key var
                        'value val)))
       sub))

(define (trail->json trail sub)
  (map (λ (crumb) (let ([left (term (term->json ,(first crumb)))]
                        [right (term (term->json ,(third crumb)))]
                        [id (fourth crumb)])
                    (hasheq 'left left
                            'right right
                            'id id)))
       trail))

(define-metafunction L
  goal->json : g -> any
  
  [(goal->json ⊤)
   ,(hasheq 'name "Succeed")]

  [(goal->json (t_1 =? t_2 o))
   ,(let* ([left-json (term (term->json  t_1))]
           [right-json (term (term->json t_2))])
      (hasheq 'name "Unify"
              'id (term o)
              'left left-json
              'right right-json))]

  [(goal->json (r t ... o))
   ,(let* ([rel-name (extract-name (symbol->string (term r)))]
           [args-json (args->json (term (t ...)))])
      (hasheq 'name "Rel-Call"
              'id (term o)
              'rel rel-name
              'args args-json))]

  [(goal->json (g_1 ∨ g_2 o))
   ,(let* ([left-json (term (goal->json g_1))]
           [right-json (term (goal->json g_2))])
      (hasheq 'name "Goal-Disj"
              'id (term o)
              'children (list left-json right-json)))]

  [(goal->json (g_1 ∧ g_2 o))
   ,(let* ([left-json (term (goal->json g_1))]
           [right-json (term (goal->json g_2))])
      (hasheq 'name "Goal-Conj"
              'id (term o)
              'children (list left-json right-json)))]

  [(goal->json (∃ d g o))
   ,(let* ([vars-json (args->json (term d))]
           [goal-json (term (goal->json g))])
      (hasheq 'name "Fresh"
              'id (term o)
              'vars vars-json
              'children (list goal-json)))])

(define-metafunction L
  tree->json : s natural -> any
  [(tree->json () _)
   ,(hasheq 'name "Empty")]

  [(tree->json (g (_ sub c trail o)) natural)
   ,(let* ([goal-json (term (goal->json g))]
           [sub-json (sub->json (term sub))]
           [trail-json (trail->json (term trail) (term sub))]
           [reified (reify (term sub) (add1 (term c)) (term natural))])
      (hash-union goal-json
                  (hasheq
                   'stateId (term o)
                   'sub sub-json
                   'trail trail-json
                   'reified reified)))]

  [(tree->json (∂ s maybe-state) natural)
   ,(let* ([tree-json (term (tree->json s natural))]
           [sub-json (if (term maybe-state) #t #f)])
      (hash-union tree-json
                  (hasheq
                    'partial #t
                    'hasAnswer sub-json)))]

  [(tree->json (proceed ((r t ... o) (_ sub c trail o_1))) natural)
   ,(let* ([goal-json (term (goal->json  (r t ...  o)))]
           [sub-json (sub->json (term sub))]
           [trail-json (trail->json (term trail) (term sub))]
           [reified (reify (term sub) (add1 (term c)) (term natural))])
      (hasheq 'name "Proceed"
              'id (term o)
              'stateId (term o_1)
              'goal goal-json
              'sub sub-json
              'trail trail-json
              'refied reified))]

  [(tree->json (s_1 +-> s_2) natural)
   ,(let* ([left-json (term (tree->json s_1 natural))]
           [right-json (term (tree->json s_2 natural))])
      (hasheq 'name "+->"
              'children (list left-json right-json)))]

  [(tree->json (s_1 <-+ s_2) natural)
   ,(let* ([left-json (term (tree->json s_1 natural))]
           [right-json (term (tree->json s_2 natural))])
      (hasheq 'name "<-+"
              'children (list left-json right-json)))]

  [(tree->json ((⊤ (_ sub c trail o)) + ()) natural)
   ,(let* ([sub-json (sub->json (term sub))]
           [trail-json (trail->json (term trail) (term sub))]
           [reified (reify (term sub) (term c) (term natural))])
      (hasheq 'name "Answer"
              'stateId (term o)
              'sub sub-json
              'trail trail-json
              'reified reified))]

  [(tree->json ((⊤ (_ sub c trail o)) + s) natural)
   ,(let* ([sub-json (sub->json (term sub))]
           [rest-json (term (tree->json s natural))]
           [trail-json (trail->json (term trail) (term sub))]
           [reified (reify (term sub) (term c) (term natural))])
      (hasheq 'name "Answer"
              'stateId (term o)
              'sub sub-json
              'trail trail-json
              'reified reified
              'children (list rest-json)))]

  [(tree->json (s × g) natural)
   ,(let* ([left-json (term (tree->json s natural))]
           [right-json (term (goal->json g))])
      (hasheq 'name "Conjunction"
              'children (list left-json right-json)))]

  [(tree->json (delay s) natural)
   ,(let* ([children (term (tree->json s natural))])
      (hasheq 'name "Delay"
              'children (list children)))])

(define-metafunction L
  prog->tree : p -> e
  [(prog->tree (e Γ)) e])

(define (to-json prog num-query-variables)
  (jsexpr->string (term (tree->json (prog->tree ,prog) ,num-query-variables))))

(define-metafunction L
  extract-query-vars : p -> d
  [(extract-query-vars (((∃ d _ _) _) _)) d])

(define (num-query-vars prog)
  (length (term (extract-query-vars ,prog))))

;; ---------- Canonical config JSON rendering ----------

(define u-rx #px"^u:([0-9]+)$")

(define (u-symbol->natural u)
  (define m (and (symbol? u) (regexp-match u-rx (symbol->string u))))
  (and m (string->number (second m))))

(define (label->id tag)
  (match tag
    [`(label ,s) s]
    [(? symbol? s) (symbol->string s)]
    [else (format "~a" tag)]))

(define (term->json/canonical t)
  (match t
    [(? symbol? x)
     (define n (u-symbol->natural x))
     (if n n (hasheq 'var (extract-name (symbol->string x))))]
    ['empty '()]
    [`(sym ,string) (hasheq 'sym string)]
    [`(nat ,natural) (hasheq 'num natural)]
    [`(str ,string) string]
    [`(,t_1 : ,t_2)
     (cons (term->json/canonical t_1)
           (list->list/canonical t_2))]
    [else t]))

(define (list->list/canonical t)
  (match t
    ['empty '()]
    [`(,t_1 : ,t_2)
     (cons (term->json/canonical t_1)
           (list->list/canonical t_2))]
    [_ (list (term->json/canonical t))]))

(define (term->reify/canonical t)
  (match t
    [(? symbol? x)
     (define n (u-symbol->natural x))
     (if n n x)]
    [`(,t_1 : ,t_2)
     `(,(term->reify/canonical t_1) : ,(term->reify/canonical t_2))]
    [`(str ,s) s]
    [_ t]))

(define (sub->json/canonical sub)
  (map (lambda (p)
         (match-define (list u t) p)
         (define key (or (u-symbol->natural u) u))
         (hasheq 'key key
                 'value (term->json/canonical t)))
       sub))

(define (trail->json/canonical trail)
  (map (lambda (crumb)
         (match crumb
           [`(,t_1 =? ,t_2 ,tag)
            (hasheq 'left (term->json/canonical t_1)
                    'right (term->json/canonical t_2)
                    'id (label->id tag))]
           [_ (hasheq 'left crumb 'right crumb 'id "bad-trail")]))
       trail))

(define (state-c-bound/canonical c)
  (cond
    [(null? c) 0]
    [else
     (add1 (for/fold ([mx -1]) ([u (in-list c)])
             (max mx (or (u-symbol->natural u) -1))))]))

(define (sub->reify/canonical sub)
  (for/list ([pr (in-list sub)])
    (match-define (list u t) pr)
    (list (or (u-symbol->natural u) u)
          (term->reify/canonical t))))

(define (goal->json/canonical g)
  (match g
    [`(succeed ,_tag)
     (hasheq 'name "Succeed")]
    [`(,t_1 =? ,t_2 ,tag)
     (hasheq 'name "Unify"
             'id (label->id tag)
             'left (term->json/canonical t_1)
             'right (term->json/canonical t_2))]
    [`(,r ,t ... ,tag)
     #:when (and (symbol? r)
                 (regexp-match? #rx"^r:" (symbol->string r)))
     (hasheq 'name "Rel-Call"
             'id (label->id tag)
             'rel (extract-name (symbol->string r))
             'args (map term->json/canonical t))]
    [`(,g_1 ∨ ,g_2 ,tag)
     (hasheq 'name "Goal-Disj"
             'id (label->id tag)
             'children (list (goal->json/canonical g_1)
                             (goal->json/canonical g_2)))]
    [`(,g_1 ∧ ,g_2 ,tag)
     (hasheq 'name "Goal-Conj"
             'id (label->id tag)
             'children (list (goal->json/canonical g_1)
                             (goal->json/canonical g_2)))]
    [`(∃ ,d ,g_1 ,tag)
     (hasheq 'name "Fresh"
             'id (label->id tag)
             'vars (map term->json/canonical d)
             'children (list (goal->json/canonical g_1)))]
    [_ (hasheq 'name "Goal")]))

(define (state->answer-json/canonical σ num-query-variables [rest #f])
  (match σ
    [`(state ,sub ,c ,trail ,tag)
     (define base
       (hasheq 'name "Answer"
               'stateId (label->id tag)
               'sub (sub->json/canonical sub)
               'trail (trail->json/canonical trail)
               'reified (reify (sub->reify/canonical sub)
                               (state-c-bound/canonical c)
                               num-query-variables)))
     (if rest
         (hash-set base 'children (list rest))
         base)]
    [_ (hasheq 'name "Answer")]))

(define (tree->json/canonical s num-query-variables)
  (match s
    ['(empty-tree)
     (hasheq 'name "Empty")]
    [`(,g (state ,sub ,c ,trail ,tag))
     (hash-union (goal->json/canonical g)
                 (hasheq 'stateId (label->id tag)
                         'sub (sub->json/canonical sub)
                         'trail (trail->json/canonical trail)
                         'reified (reify (sub->reify/canonical sub)
                                         (state-c-bound/canonical c)
                                         num-query-variables)))]
    [`(proceed ((,r ,t ... ,tag-call) (state ,sub ,c ,trail ,tag-state)))
     (hasheq 'name "Proceed"
             'id (label->id tag-call)
             'stateId (label->id tag-state)
             'goal (goal->json/canonical `(,r ,@t ,tag-call))
             'sub (sub->json/canonical sub)
             'trail (trail->json/canonical trail)
             'reified (reify (sub->reify/canonical sub)
                             (state-c-bound/canonical c)
                             num-query-variables))]
    [`(proceed (,g (state ,sub ,c ,trail ,tag-state)))
     (hasheq 'name "Proceed"
             'id (label->id tag-state)
             'stateId (label->id tag-state)
             'goal (goal->json/canonical g)
             'sub (sub->json/canonical sub)
             'trail (trail->json/canonical trail)
             'reified (reify (sub->reify/canonical sub)
                             (state-c-bound/canonical c)
                             num-query-variables))]
    [`(,s_1 <-+ ,s_2)
     (hasheq 'name "<-+"
             'children (list (tree->json/canonical s_1 num-query-variables)
                             (tree->json/canonical s_2 num-query-variables)))]
    [`(,s_1 +-> ,s_2)
     (hasheq 'name "+->"
             'children (list (tree->json/canonical s_1 num-query-variables)
                             (tree->json/canonical s_2 num-query-variables)))]
    [`(,s_1 × ,g ,_c)
     (hasheq 'name "Conjunction"
             'children (list (tree->json/canonical s_1 num-query-variables)
                             (goal->json/canonical g)))]
    [`(delay ,s_1)
     (hasheq 'name "Delay"
             'children (list (tree->json/canonical s_1 num-query-variables)))]
    [`(⊤ ,σ)
     (state->answer-json/canonical σ num-query-variables)]
    [_ (hasheq 'name "Unknown")]))

(define (config->tree-json/canonical cfg num-query-variables)
  (match cfg
    [`(,_gamma ,ans* ,s)
     (for/fold ([acc (tree->json/canonical s num-query-variables)])
               ([σ (in-list (reverse ans*))])
       (define empty? (equal? (hash-ref acc 'name #f) "Empty"))
       (state->answer-json/canonical σ
                                     num-query-variables
                                     (and (not empty?) acc)))]
    [_ (hasheq 'name "Empty")]))

(define (to-json/canonical cfg num-query-variables)
  (jsexpr->string (config->tree-json/canonical cfg num-query-variables)))

(define (goal-query-vars/canonical g)
  (match g
    [`(∃ ,d ,_ ,_) (length d)]
    [`(,g_1 ∧ ,g_2 ,_) (max (goal-query-vars/canonical g_1)
                            (goal-query-vars/canonical g_2))]
    [`(,g_1 ∨ ,g_2 ,_) (max (goal-query-vars/canonical g_1)
                            (goal-query-vars/canonical g_2))]
    [_ 0]))

(define (num-query-vars/canonical cfg)
  (match cfg
    [`(,_gamma ,_ans* (,g ,_σ)) (goal-query-vars/canonical g)]
    [`(,_gamma ,_ans* (,s_1 × ,g ,_c))
     (max (num-query-vars/canonical `(() () ,s_1))
          (goal-query-vars/canonical g))]
    [`(,_gamma ,_ans* (,s_1 <-+ ,s_2))
     (max (num-query-vars/canonical `(() () ,s_1))
          (num-query-vars/canonical `(() () ,s_2)))]
    [`(,_gamma ,_ans* (,s_1 +-> ,s_2))
     (max (num-query-vars/canonical `(() () ,s_1))
          (num-query-vars/canonical `(() () ,s_2)))]
    [`(,_gamma ,_ans* (delay ,s_1))
     (num-query-vars/canonical `(() () ,s_1))]
    [`(,_gamma ,_ans* (proceed (,g ,_σ)))
     (goal-query-vars/canonical g)]
    [_ 0]))
