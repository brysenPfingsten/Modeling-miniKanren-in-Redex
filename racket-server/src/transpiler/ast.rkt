#lang racket

(provide (struct-out prog)
         (struct-out fresh)
         (struct-out conde)
         (struct-out disj)
         (struct-out conj)
         (struct-out unify)
         (struct-out diseq)
         (struct-out delay-goal)
         (struct-out compiled-delay-goal)
         (struct-out succeed)
         (struct-out fail)
         (struct-out relcall)
         (struct-out nil)
         (struct-out konst)
         (struct-out kons)
         (struct-out var)
         (struct-out relname)
         (struct-out defrel)
         (struct-out run)
         konst->string
         term->string
         map/kons
         kons->string
         add-guids
         source-occurrence-ids
         inherit-source-id!
         primitive-value?
         parse-term-within-quote
         kons*-terms
         parse-term-within-qquote
         parse-term)

(struct prog (relations query) #:transparent)
(struct fresh (vars goal) #:transparent)
(struct conde (clauses) #:transparent)
(struct disj (g1 g2) #:transparent)
(struct conj (g1 g2) #:transparent)
(struct unify (t1 t2) #:transparent)
(struct diseq (t1 t2) #:transparent)
(struct delay-goal (goal) #:transparent)
(struct compiled-delay-goal (goal) #:transparent)
(struct succeed () #:transparent)
(struct fail () #:transparent)
(struct relcall (name terms) #:transparent)
(struct nil () #:transparent)
(struct konst (k) #:transparent)
(struct kons (a d) #:transparent)
(struct var (v) #:transparent)
(struct relname (name) #:transparent)
(struct defrel (name lop goal) #:transparent)
(struct run (n q goal) #:transparent)

(define (next-g-id prefix counter)
  (values (string-append prefix (number->string counter)) (add1 counter)))

;; Compilation metadata keyed by source occurrence, not structural equality:
;; two identical goals in the source still denote two different locations.
;; The normalizer explicitly preserves this identity when rebuilding nodes.
(define (source-occurrence-ids ast)
  (define ids (make-hasheq))
  (define (visit expr count)
    (define prefix
      (match expr
        [(or (fresh _ _) (run _ _ _)) "f"]
        [(or (conde _) (disj _ _)) "d"]
        [(conj _ _) "c"]
        [(unify _ _) "u"]
        [(diseq _ _) "n"]
        [(delay-goal _) "y"]
        [(relcall _ _) "r"]
        [(succeed) "s"]
        [(fail) "fail"]
        [_ #f]))
    (define next
      (if prefix
          (let-values ([(id next) (next-g-id prefix count)])
            (hash-set! ids expr id)
            next)
          count))
    (match expr
      [(prog rels query)
       (visit query (for/fold ([n next]) ([rel (in-list rels)]) (visit rel n)))]
      [(defrel _ _ goal) (visit goal next)]
      [(or (fresh _ goal) (run _ _ goal) (delay-goal goal)) (visit goal next)]
      [(conde clauses)
       (for/fold ([n next]) ([clause (in-list clauses)]) (visit clause n))]
      [(or (conj left right) (disj left right)) (visit right (visit left next))]
      [_ next]))
  (visit ast 0)
  ids)

(define (inherit-source-id! ids source rebuilt)
  (hash-set! ids rebuilt (hash-ref ids source))
  rebuilt)

(define (konst->string const)
  (match const
    [(struct konst (s)) #:when (symbol? s) (format "'~s" s)]
    [(struct konst (s)) #:when (string? s) (format "~s" s)]
    [(struct konst (b)) #:when (boolean? b) (if b "#t" "#f")]
    [(struct konst (n)) #:when (number? n) (number->string n)]))

(define (term->string t)
  (cond
    [(konst? t) (konst->string t)]
    [(nil? t) "'()"]
    [(var? t) (format "~s" (var-v t))]
    [(relname? t) (format "~s" (relname-name t))]
    [(kons? t) (kons->string t)]
    [else t]))

(define (map/kons f k)
  (match k
    [_ #:when (nil? k) '()]
    [(struct kons (a d))
     (cons (f a) (map/kons f d))]
    [_ (list (f k))]))

(define (kons->string l)
  (let* ([l^ (map/kons term->string l)]
         [l^^ (string-join l^ " ")]
         [d (kons-d l)])
    (if (or (kons? d) (nil? d))
        (format "(list ~a)" l^^)
        (format "(cons ~a)" l^^))))

(define (kons->string/help l)
  (match l
    [(struct kons (a nil-tail)) #:when (nil? nil-tail)
     (kons->string/help a)]
    [(struct var (v))
     (format "~s" v)]
    [(struct konst (_k))
     (konst->string l)]
    [(struct kons (a d))
     (format "~a ~a"
             (kons->string/help a)
             (kons->string/help d))]))

(define (add-guids expr s source-ids [source-mode "mini"])
  (define padding (make-string s #\space))
  (define body
    (match expr
      [(prog rels query)
       (string-append
        (string-join (map (lambda (rel) (add-guids rel 0 source-ids source-mode)) rels) "\n\n")
        "\n\n" (add-guids query 0 source-ids source-mode))]
      [(fresh vars goal)
       (format "(fresh (~a)\n~a)"
               (string-join (map term->string vars) " ")
               (add-guids goal (+ s 2) source-ids source-mode))]
      [(conde clauses)
       (format "(conde\n~a\n~a)"
               (string-join
                (for/list ([clause (in-list clauses)])
                  (format "~a[~a]" (make-string (+ s 2) #\space)
                          (substring (add-guids clause (+ s 2) source-ids source-mode) (+ s 2))))
                "\n")
               padding)]
      [(conj left right)
       (if (equal? source-mode "micro")
           (format "(conj\n~a\n~a\n~a)"
                   (add-guids left (+ s 2) source-ids source-mode)
                   (add-guids right (+ s 2) source-ids source-mode)
                   padding)
           (format "~a\n~a"
                   (substring (add-guids left s source-ids source-mode) s)
                   (add-guids right s source-ids source-mode)))]
      [(unify left right) (format "(== ~a ~a)" (term->string left) (term->string right))]
      [(diseq left right) (format "(=/= ~a ~a)" (term->string left) (term->string right))]
      [(succeed) "succeed"]
      [(fail) "fail"]
      [(disj left right)
       (format "(disj\n~a\n~a\n~a)"
               (add-guids left (+ s 2) source-ids source-mode)
               (add-guids right (+ s 2) source-ids source-mode)
               padding)]
      [(relcall name arguments)
       (format "(~a~a)" (term->string name)
               (if (null? arguments) ""
                   (string-append " " (string-join (map term->string arguments) " "))))]
      [(defrel name vars goal)
       (format "(defrel (~a~a)\n~a)"
               (term->string name)
               (if (null? vars) "" (string-append " " (string-join (map term->string vars) " ")))
               (add-guids goal (+ s 2) source-ids source-mode))]
      [(run n vars goal)
       (format "(run~a (~a) ~a)"
               (if (= n +inf.0) "*" (format " ~a" n))
               (string-join (map term->string vars) " ")
               (substring (add-guids goal s source-ids source-mode) s))]
      [(delay-goal goal)
       (format "(Zzz\n~a\n~a)" (add-guids goal (+ s 2) source-ids source-mode) padding)]
      [_ (term->string expr)]))
  (define id (hash-ref source-ids expr #f))
  (string-append padding (if id (format "[[~a]]~a[[/~a]]" id body id) body)))

(define (primitive-value? v)
  (or (symbol? v)
      (string? v)
      (boolean? v)
      (number? v)))

(define (parse-term-within-quote t)
  (match t
    [(cons qta qtb) (kons (parse-term-within-quote qta)
                          (parse-term-within-quote qtb))]
    [k #:when (primitive-value? k) (konst k)]
    ['() (nil)]))

(define (kons*-terms lot)
  (foldr kons (nil) lot))

(define (parse-term-within-qquote t)
  (match t
    [(list 'unquote expr) (parse-term expr)]
    [(cons qta qtb) (kons (parse-term-within-qquote qta)
                          (parse-term-within-qquote qtb))]
    [k #:when (primitive-value? k) (konst k)]
    ['() (nil)]))

(define (parse-term t)
  (match t
    [`(quote ,subterm) (parse-term-within-quote subterm)]
    [`(quasiquote ,expr) (parse-term-within-qquote expr)]
    [`(cons ,ta ,td) (kons (parse-term ta) (parse-term td))]
    [`(list . ,args) (kons*-terms (map parse-term args))]
    [sym #:when (symbol? sym) (var sym)]
    [k #:when (primitive-value? k) (konst k)]))
