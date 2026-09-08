#lang racket
(require rackunit
         rackunit/text-ui
         redex/reduction-semantics
         (prefix-in production:
                    "../derivations/shared/relation-grammar.rkt")
         (prefix-in wf:
                    "../derivations/shared/wf.rkt")
         "../src/sexpr-read.rkt"
         "../src/transpiler.rkt"
         (prefix-in ast: "../src/transpiler/ast.rkt")
         (only-in "../src/transpiler/program.rkt" prepare-program)
         (only-in "../derivations/shared/kernel.rkt"
                  instantiate-relation allocate/s))

(define (parse-src/canonical src
                             #:source-mode [source-mode default-source-mode]
                             #:compile-profile [compile-profile #f])
  (parse-prog/canonical (read-all-sexprs (open-input-string src))
                        #:source-mode source-mode
                        #:compile-profile compile-profile))

(define (parse-src/ast src
                       #:source-mode [source-mode default-source-mode]
                       #:compile-profile [compile-profile #f])
  (parse-prog->ast (read-all-sexprs (open-input-string src))
                   #:source-mode source-mode
                   #:compile-profile compile-profile))

(define (query-goal-of cfg)
  (match cfg
    [`(program ,_ (commit (eval (Owners) (∃ ,_ ,goal ,_) ,_))) goal]
    [_ (error 'query-goal-of "unexpected production cfg shape: ~e" cfg)]))

(define (relation-goal-of cfg rel-name)
  (match cfg
    [`(program ,rels ,_)
     (define maybe-goal
       (for/first ([rel (in-list rels)]
                   #:when (match rel
                            [`(,r ,_ ,_)
                             (equal? r rel-name)]
                            [_ #f]))
         (match rel
           [`(,_ ,_ ,goal) goal]
           [_ #f])))
     (or maybe-goal
         (error 'relation-goal-of
                "relation ~e not present in production cfg ~e"
                rel-name
                cfg))]
    [_ (error 'relation-goal-of "unexpected production cfg shape: ~e" cfg)]))

(define (goal-top-delay? goal)
  (match goal
    [`(suspend ,_ ,_) #t]
    [_ #f]))

(define (goal-contains-delay? goal [seen #f])
  (match goal
    [`(suspend ,g ,_)
     (goal-contains-delay? g #t)]
    [`(∃ ,_ ,g ,_)
     (goal-contains-delay? g seen)]
    [`(,g1 ∧ ,g2 ,_)
     (or (goal-contains-delay? g1 seen)
         (goal-contains-delay? g2 seen))]
    [`(,g1 ∨ ,g2 ,_)
     (or (goal-contains-delay? g1 seen)
         (goal-contains-delay? g2 seen))]
    [_ seen]))

(define (strip-suspends goal)
  (match goal
    [`(suspend ,g ,_) (strip-suspends g)]
    [`(∃ ,vars ,g ,tag) `(∃ ,vars ,(strip-suspends g) ,tag)]
    [`(,g1 ∧ ,g2 ,tag) `(,(strip-suspends g1) ∧ ,(strip-suspends g2) ,tag)]
    [`(,g1 ∨ ,g2 ,tag) `(,(strip-suspends g1) ∨ ,(strip-suspends g2) ,tag)]
    [_ goal]))

(define (goal-contains-delayed-relcall? goal)
  (match goal
    [`(suspend (,r ,_ ... ,_) ,_)
     (and (symbol? r)
          (regexp-match? #rx"^r:" (symbol->string r)))]
    [`(suspend ,g ,_)
     (goal-contains-delayed-relcall? g)]
    [`(∃ ,_ ,g ,_)
     (goal-contains-delayed-relcall? g)]
    [`(,g1 ∧ ,g2 ,_)
     (or (goal-contains-delayed-relcall? g1)
         (goal-contains-delayed-relcall? g2))]
    [`(,g1 ∨ ,g2 ,_)
     (or (goal-contains-delayed-relcall? g1)
         (goal-contains-delayed-relcall? g2))]
    [_ #f]))

(define (strip-labels x)
  (match x
    [`(label ,_) '(label "_")]
    [(cons a d) (cons (strip-labels a) (strip-labels d))]
    [_ x]))

;; These attribution fixtures contain no marker text in literals (the literal
;; escaping tests below cover that separately). Inspect the actual emitted
;; spans, independently of the compiler's source-identity map.
(define (display-spans markup)
  (define marker #px"\\[\\[(/?)([a-z]+[0-9]+)\\]\\]")
  (define-values (plain stack spans last-index)
    (for/fold ([plain ""] [stack '()] [spans '()] [last-index 0])
              ([position (in-list (regexp-match-positions* marker markup))])
      (match-define (cons start end) position)
      (match-define (list _ close id) (regexp-match marker (substring markup start end)))
      (define next-plain (string-append plain (substring markup last-index start)))
      (if (equal? close "")
          (values next-plain (cons (list id (string-length next-plain)) stack) spans end)
          (match stack
            [(cons (list (== id) beginning) rest)
             (values next-plain rest (cons (list id beginning (string-length next-plain)) spans) end)]))))
  (check-equal? stack '())
  (values (string-append plain (substring markup last-index)) (reverse spans)))

(define (source-goals ast [acc '()])
  (match ast
    [(ast:prog rels query) (foldr source-goals (source-goals query acc) rels)]
    [(ast:defrel _ _ goal) (source-goals goal acc)]
    [(or (ast:run _ _ goal) (ast:fresh _ goal) (ast:delay-goal goal))
     (cons ast (source-goals goal acc))]
    [(ast:conde clauses) (cons ast (foldr source-goals acc clauses))]
    [(or (ast:conj left right) (ast:disj left right))
     (cons ast (source-goals left (source-goals right acc)))]
    [_ (cons ast acc)]))

(define (source-leaf? goal)
  (or (ast:unify? goal) (ast:diseq? goal) (ast:relcall? goal)
      (ast:succeed? goal) (ast:fail? goal)))

(define (compiled-goals goal [acc '()])
  (match goal
    [`(∃ ,_ ,body ,_) (cons goal (compiled-goals body acc))]
    [`(suspend ,body ,_) (cons goal (compiled-goals body acc))]
    [`(,left ,(or '∧ '∨) ,right ,_)
     (cons goal (compiled-goals left (compiled-goals right acc)))]
    [_ (cons goal acc)]))

(define (compiled-leaf? goal)
  (match goal
    [(or `(∃ ,_ ,_ ,_) `(suspend ,_ ,_) `(,_ ,(or '∧ '∨) ,_ ,_)) #f]
    [_ #t]))

(define (compiled-term->source term)
  (match term
    [`(sym ,name) `(quote ,(string->symbol name))]
    [`(str ,value) value]
    [`(nat ,value) value]
    [(? boolean?) term]
    ['empty '(quote ())]
    [`(,left : ,right) `(cons ,(compiled-term->source left) ,(compiled-term->source right))]
    [(? symbol?) (string->symbol (substring (symbol->string term) 2))]))

(define (compiled-leaf->source goal)
  (match goal
    [`(,left ,(and op (or '=? '!=)) ,right ,_)
     `(,(if (eq? op '=?) '== '=/=) ,(compiled-term->source left) ,(compiled-term->source right))]
    [`(,(and op (or 'succeed 'fail)) ,_) op]
    [`(,name ,arguments ... ,_)
     `(,(compiled-term->source name) ,@(map compiled-term->source arguments))]))

(define (assert-source-attribution! forms [mode "mini"] [profile #f])
  (define-values (_normalized original _profile ids) (prepare-program forms mode profile))
  (define-values (cfg markup _query)
    (parse-prog/canonical forms #:source-mode mode #:compile-profile profile))
  (define-values (plain spans) (display-spans markup))
  (match-define `(program ,definitions (commit (eval ,_ ,query-goal ,_))) cfg)
  (define goals
    (foldr (lambda (definition rest) (compiled-goals (third definition) rest))
           (compiled-goals query-goal) definitions))
  (define originals (source-goals original))
  (define original-leaves (filter source-leaf? originals))
  (define expected
    (for/list ([leaf (in-list original-leaves)])
      (list (read (open-input-string (ast:add-guids leaf 0 #hasheq() mode))) (hash-ref ids leaf))))
  (check-equal? (length (remove-duplicates (map second expected))) (length expected))
  (check-equal?
   (for/list ([leaf (in-list (filter compiled-leaf? goals))])
     (list (compiled-leaf->source leaf) (second (last leaf))))
   expected)
  (for ([source (in-list originals)]
        #:when (or (source-leaf? source) (ast:fresh? source) (ast:delay-goal? source)))
    (check-not-false (assoc (hash-ref ids source) spans)))
  (for ([entry (in-list expected)])
    (match-define (list source id) entry)
    (match-define (list _ start end) (assoc id spans))
    (check-equal? (read (open-input-string (substring plain start end))) source))
  ;; Every visible compiled operation owns one actual source span; all of its
  ;; descendant leaves lie inside that span, including generated binary nodes.
  (for ([goal (in-list goals)])
    (define id (second (last goal)))
    (cond
      [(string-prefix? id "hidden:") (check-false (assoc id spans))]
      [else
       (match-define (list _ start end) (assoc id spans))
       (for ([leaf (in-list (filter compiled-leaf? (compiled-goals goal)))])
         (match-define (list _ leaf-start leaf-end) (assoc (second (last leaf)) spans))
         (check-true (<= start leaf-start leaf-end end)))]))
  (define-values (roundtrip _markup _metadata)
    (parse-src/canonical plain #:source-mode mode #:compile-profile profile))
  (check-equal? roundtrip cfg)
  expected)

(define conj-source
  "(run* (q) (== 1 1) (== 2 2) (== 3 3))")

(define disj-source
  "(run* (q)
     (conde
       [(== q 'a)]
       [(== q 'b)]
       [(== q 'c)]))")

(define relcall-source
  "(defrel (same x y)
     (== x y))

   (defrel (wrap x)
     (== x x)
     (same x 'cat))

   (run* (q)
     (wrap q))")

(define micro-source
  "(defrel (same x y)
     (Zzz (conj (== x y) (=/= x 'dog))))

   (run* (q)
     (disj (same q 'cat)
           (Zzz (== q 'dog))))")

(define (profile-jsexpr conj-assoc disj-assoc delay-placement)
  (hasheq 'conjAssoc conj-assoc
          'disjAssoc disj-assoc
          'delayPlacement delay-placement))

(define-test-suite SOURCE-MODES
  (test-case "normalize-source-mode defaults missing or blank inputs"
    (check-equal? (normalize-source-mode #f) default-source-mode)
    (check-equal? (normalize-source-mode "") default-source-mode))

  (test-case "normalize-source-mode preserves supported modes"
    (check-equal? (normalize-source-mode "mini") "mini")
    (check-equal? (normalize-source-mode "micro") "micro"))

  (test-case "normalize-source-mode rejects unsupported values"
    (check-exn
     (lambda (e)
       (and (exn:fail? e)
            (regexp-match? #rx"unsupported sourceMode" (exn-message e))))
     (thunk (normalize-source-mode "macro")))))

(define-test-suite ASSOCIATIVITY
  (test-case "Conjunctions Left Associate"
    (define PROG '((run* (q) (== 1 1) (== 2 2) (== 3 3))))
    (define-values (cfg _ _cfg-query) (parse-prog/canonical PROG))
    (define goal (query-goal-of cfg))
    (check-true (redex-match? production:StrictSRel g (term ,goal)))
    (check-true
     (match goal
       [`((,_ ∧ ,_ ,_) ∧ ,_ ,_) #t]
       [_ #f])))

  (test-case "Disjunctions Right Associate"
    (define PROG '((run* (q)
                    (conde
                      [(conde
                        [(same q 'turtle)]
                        [(same q 'cat)]
                        [(== q 'dog)])]
                      [(same q 'fish)]))))
    (define-values (cfg _ _cfg-query) (parse-prog/canonical PROG))
    (define goal (query-goal-of cfg))
    (check-true (redex-match? production:StrictSRel g (term ,goal)))
    (check-true
     (match goal
       [`((,_ ∨ (,_ ∨ ,_ ,_) ,_) ∨ ,_ ,_) #t]
       [_ #f]))

    (define PROG1 '((run* (q)
                      (conde
                        ((conde
                          ((same q 'turtle))
	                      ((conde
	                          ((same q 'cat))
	                          ((== q 'dog))))))
                            ((same q 'fish))))))
    (define-values (cfg1 _1 _cfg1-query) (parse-prog/canonical PROG1))
    (define goal1 (query-goal-of cfg1))
    (check-true
     (match goal1
       [`((,_ ∨ (,_ ∨ ,_ ,_) ,_) ∨ ,_ ,_) #t]
       [_ #f]))

    (define PROG2 '((run* (q)
                    (conde
                      [(same q 'turtle)]
                      [(same q 'cat)]
                      [(== q 'dog)]
                      [(same q 'fish)]))))
    (define-values (cfg2 _2 _cfg2-query) (parse-prog/canonical PROG2))
    (define goal2 (query-goal-of cfg2))
    (check-true
     (match goal2
       [`(,_ ∨ (,_ ∨ (,_ ∨ ,_ ,_) ,_) ,_) #t]
       [_ #f]))
    ))

(define-test-suite COMPILE-PROFILES
  (test-case "all 12 compile profiles preserve selected conjunction/disjunction shape"
    (for* ([conj-assoc (in-list '("left" "right"))]
           [disj-assoc (in-list '("left" "right"))]
           [delay-placement (in-list '("relbody" "relcall" "disj"))])
      (define profile
        (profile-jsexpr conj-assoc disj-assoc delay-placement))

      (define-values (conj-cfg _conj-html _conj-cfg-query)
        (parse-src/canonical conj-source #:compile-profile profile))
      (define conj-goal (query-goal-of conj-cfg))
      (cond
        [(equal? conj-assoc "left")
         (check-true
          (match conj-goal
            [`((,_ ∧ ,_ ,_) ∧ ,_ ,_) #t]
            [_ #f])
          (format "expected left-associated conjunction for profile ~e, got ~e"
                  profile
                  conj-goal))]
        [else
         (check-true
          (match conj-goal
            [`(,_ ∧ (,_ ∧ ,_ ,_) ,_) #t]
            [_ #f])
          (format "expected right-associated conjunction for profile ~e, got ~e"
                  profile
                  conj-goal))])

      (define-values (disj-cfg _disj-html _disj-cfg-query)
        (parse-src/canonical disj-source #:compile-profile profile))
      (define disj-goal (query-goal-of disj-cfg))
      (define disj-inner
        (match disj-goal
          [`(suspend ,inner ,_) inner]
          [_ disj-goal]))
      (define stripped-disj (strip-suspends disj-inner))
      (check-equal? (goal-top-delay? disj-goal)
                    (equal? delay-placement "disj")
                    (format "disjunction delay placement mismatch for profile ~e: ~e"
                            profile
                            disj-goal))
      (cond
        [(equal? disj-assoc "left")
         (check-true
          (match stripped-disj
            [`((,_ ∨ ,_ ,_) ∨ ,_ ,_) #t]
            [_ #f])
          (format "expected left-associated disjunction for profile ~e, got ~e"
                  profile
                  disj-inner))]
        [else
         (check-true
          (match stripped-disj
            [`(,_ ∨ (,_ ∨ ,_ ,_) ,_) #t]
            [_ #f])
          (format "expected right-associated disjunction for profile ~e, got ~e"
                  profile
                  disj-inner))])))

  (test-case "delay placement distinguishes query relcalls from relation bodies"
    (for* ([conj-assoc (in-list '("left" "right"))]
           [disj-assoc (in-list '("left" "right"))]
           [delay-placement (in-list '("relbody" "relcall" "disj"))])
      (define profile
        (profile-jsexpr conj-assoc disj-assoc delay-placement))
      (define-values (cfg _html _cfg-query)
        (parse-src/canonical relcall-source #:compile-profile profile))
      (define query-goal (query-goal-of cfg))
      (define wrap-goal (relation-goal-of cfg 'r:wrap))
      (check-equal? (goal-top-delay? query-goal)
                    (equal? delay-placement "relcall")
                    (format "query relcall delay mismatch for profile ~e: ~e"
                            profile
                            query-goal))
      (case (string->symbol delay-placement)
        [(relbody)
         (check-true (goal-top-delay? wrap-goal)
                     (format "wrap body should be whole-body delayed for profile ~e: ~e"
                             profile
                             wrap-goal))]
        [(relcall)
         (check-false (goal-top-delay? wrap-goal)
                      (format "wrap body should not be whole-body delayed for profile ~e: ~e"
                              profile
                              wrap-goal))
         (check-true (goal-contains-delayed-relcall? wrap-goal)
                     (format "wrap body should contain a delayed relcall for profile ~e: ~e"
                             profile
                             wrap-goal))]
        [(disj)
         (check-false (goal-contains-delay? wrap-goal)
                      (format "wrap body should not contain compiler delay for profile ~e: ~e"
                              profile
                              wrap-goal))]))))

  (test-case "normalize-compile-profile rejects unsupported axis values"
    (check-exn
     (lambda (e)
       (and (exn:fail? e)
            (regexp-match? #rx"invalid compileProfile\\.conjAssoc"
                           (exn-message e))))
     (thunk
      (normalize-compile-profile
       (hasheq 'conjAssoc "middle"
               'disjAssoc "right"
               'delayPlacement "relbody")))))

(define-test-suite MICRO-SOURCE
  (test-case "direct micro source accepts binary conj/disj, Zzz, and disequality"
    (define-values (cfg html _cfg-query)
      (parse-src/canonical micro-source #:source-mode "micro"))
    (check-true (redex-match? production:StrictSRel p cfg))
    (check-true (wf:wf-s-rel? cfg))
    (check-true (string? html)))

  (test-case "direct micro source rejects source-level delay spelling"
    (check-exn
     exn:fail?
     (lambda ()
       (parse-src/canonical
        "(run* (q) (delay (== q 'cat)))"
        #:source-mode "micro"))))

  (test-case "direct micro source rejects conde"
    (check-exn
     exn:fail?
     (lambda ()
       (parse-src/canonical
        "(run* (q) (conde [(== q 'cat)] [(== q 'dog)]))"
        #:source-mode "micro"))))

  (test-case "direct micro source rejects proceed"
    (check-exn
     exn:fail?
     (lambda ()
       (parse-src/canonical
        "(run* (q) (proceed (== q 'cat)))"
        #:source-mode "micro"))))

  (test-case "direct micro source rejects multi-goal defrel bodies"
    (check-exn
     exn:fail?
     (lambda ()
       (parse-src/canonical
        "(defrel (same x y)
           (== x y)
           (== y x))
         (run* (q) (same q 'cat))"
        #:source-mode "micro"))))

  (test-case "direct micro source rejects multi-goal run tails"
    (check-exn
     exn:fail?
     (lambda ()
       (parse-src/canonical
        "(run* (q) (== q 'cat) (== q 'dog))"
        #:source-mode "micro")))))

(define-test-suite MICRO-RENDERING
  (test-case "rendered micro source round-trips mini compilation for all compile profiles"
    (for* ([conj-assoc (in-list '("left" "right"))]
           [disj-assoc (in-list '("left" "right"))]
           [delay-placement (in-list '("relbody" "relcall" "disj"))])
      (define profile
        (profile-jsexpr conj-assoc disj-assoc delay-placement))
      (define rendered
        (render-micro-source (read-all-sexprs (open-input-string relcall-source))
                             #:compile-profile profile))
      (check-equal? (not (false? (regexp-match? #rx"Zzz" rendered)))
                    (not (equal? delay-placement "disj"))
                    (format "rendered micro delay visibility mismatch for ~e" profile))
      (define-values (expected-cfg _expected-html _expected-cfg-query)
        (parse-src/canonical relcall-source #:compile-profile profile))
      (define-values (rendered-cfg _rendered-html _rendered-cfg-query)
        (parse-src/canonical rendered #:source-mode "micro"))
      (check-equal? (strip-labels expected-cfg)
                    (strip-labels rendered-cfg)
                    (format "rendered micro should round-trip the production config modulo labels for ~e"
                            profile)))))

(define-test-suite DISEQUALITY-TRANSLATION
  (test-case "mini source translates disequality to production != goal"
    (define-values (cfg _html _cfg-query)
      (parse-src/canonical "(run* (q) (=/= q 'cat))"))
    (define goal (query-goal-of cfg))
    (check-true (redex-match? production:StrictSRel g (term ,goal)))
    (check-true
     (match goal
       [`(,_ != ,_ ,_) #t]
       [_ #f])))

  (test-case "micro source translates disequality to canonical != goal"
    (define-values (cfg _html _cfg-query)
      (parse-src/canonical "(run* (q) (=/= q 'cat))" #:source-mode "micro"))
    (define goal (query-goal-of cfg))
    (check-true (redex-match? production:StrictSRel g (term ,goal)))
    (check-true
     (match goal
       [`(,_ != ,_ ,_) #t]
       [_ #f]))))

(define-test-suite PRODUCTION-TRANSLATION
  (test-case
   "run*-only canonicalizing compilation produces a strict matrix configuration and is wf"
   (define-values (cfg html _cfg-query)
     (parse-src/canonical "(run* (q) (== 'a 'a))"))
   (check-match cfg `(program ,_ (commit (eval (Owners) ,_ ,_))))
   (check-true (redex-match? production:StrictSRel p cfg))
   (check-true (wf:wf-s-rel? cfg))
   (check-true (string? html)))

  (test-case
   "defrel+run* canonicalizing compilation produces a strict matrix configuration and is wf"
   (define-values (cfg html _cfg-query)
     (parse-src/canonical
      "(defrel (same x y) (== x y))
(run* (q) (same q 'cat))"))
   (check-match cfg `(program ,_ (commit (eval (Owners) ,_ ,_))))
   (check-true (redex-match? production:StrictSRel p cfg))
   (check-true (wf:wf-s-rel? cfg))
   (check-true (string? html)))

  (test-case
   "relation-call arity mismatch parses but is rejected by wf"
   (define-values (cfg _html _cfg-query)
     (parse-src/canonical
      "(defrel (same x y) (== x y))
(run* (q) (same q))"))
   (check-true (redex-match? production:StrictSRel p cfg))
   (check-false (wf:wf-s-rel? cfg)))

  (test-case "tagged source writes strings and symbols without changing their canonical values"
    (for* ([mode (in-list '("mini" "micro"))]
           [literal (in-list (list "[[u0]]"
                                   "[[/u1]]  [[u1]]"
                                   "escaped \" [[/u1]] \\ end"
                                   "first line\n[[u1]]  last line"
                                   (string->symbol "[[u1]]")
                                   (string->symbol "a\"[[/u1]]\\b")
                                   (string->symbol "[[u1]]|")))])
      (define datum (if (symbol? literal) `(quote ,literal) literal))
      (define forms `((run* (q) (== q ,datum))))
      (define-values (cfg html _query)
        (parse-prog/canonical forms #:source-mode mode))
      (define written
        (if (symbol? literal) (format "'~s" literal) (format "~s" literal)))
      (check-equal? html
                    (format "\n\n[[f0]](run* (q) [[u1]](== q ~a)[[/u1]])[[/f0]]" written))
      (check-equal? (query-goal-of cfg)
                    `(x:q =? ,(if (symbol? literal)
                                  `(sym ,(symbol->string literal))
                                  `(str ,literal))
                          (label "u1")))
      ;; The displayed written atom reads back to the same source and machine.
      (define-values (displayed-cfg _displayed-html _displayed-query)
        (parse-src/canonical (format "(run* (q) (== q ~a))" written)
                             #:source-mode mode))
      (check-equal? displayed-cfg cfg)))

  (test-case "conde formatting preserves literal whitespace and nested list atoms"
    (define literal "[[u1]]  [[/u1]]\n  trailing spaces  ")
    (define symbol-literal (string->symbol "[[u1]]|"))
    (define forms
      `((run* (q)
          (conde
            [(== q ,literal)]
            [(== q (list ,literal (quote ,symbol-literal)))
             (=/= q ,literal)]))))
    (define-values (cfg html _query) (parse-prog/canonical forms))
    (check-true (string-contains? html (format "(== q ~s)" literal)))
    (check-true (string-contains? html (format "(=/= q ~s)" literal)))
    (check-true
     (string-contains? html (format "(list ~s '~s)" literal symbol-literal)))
    (define-values (micro-cfg _micro-html _micro-query)
      (parse-src/canonical (render-micro-source forms) #:source-mode "micro"))
    (check-equal? (strip-labels micro-cfg) (strip-labels cfg)))

  (test-case "tagged source writes delimiter-containing variable and relation names"
    (define query-name (string->symbol "[[q]]"))
    (define relation-name (string->symbol "some|relation"))
    (define forms
      `((defrel (,relation-name ,query-name) (== ,query-name ,query-name))
        (run* (,query-name) (,relation-name ,query-name))))
    (define-values (cfg html _query) (parse-prog/canonical forms))
    (check-true
     (string-contains? html (format "(defrel (~s ~s)" relation-name query-name)))
    (check-true
     (string-contains? html (format "(== ~s ~s)" query-name query-name)))
    (check-true
     (string-contains? html (format "(~s ~s)" relation-name query-name)))
    (define-values (micro-cfg _micro-html _micro-query)
      (parse-src/canonical (render-micro-source forms) #:source-mode "micro"))
    (check-equal? (strip-labels micro-cfg) (strip-labels cfg)))

  )

(define-test-suite SOURCE-ATTRIBUTION
  (test-case "all mini profiles preserve original occurrence IDs and actual source spans"
    (define forms
      '((defrel (same x y) (== x y))
        (run* (q)
          (fresh (x)
            (== x q)
            (same q q)
            (same q q)
            (conde
              [(conde [(same q 'turtle)] [(same q 'cat)] [(== q 'dog)])]
              [(fresh (x) (== x 'fish) (== x q) (same x q))]
              [(== q 'bird)]
              [(== q 'mouse)])))))
    (for*/fold ([reference #f])
               ([conj (in-list '("left" "right"))]
                [disj (in-list '("left" "right"))]
                [delay (in-list '("relbody" "relcall" "disj"))])
      (define actual (assert-source-attribution! forms "mini" (profile-jsexpr conj disj delay)))
      (when reference (check-equal? actual reference))
      actual))

  (test-case "single-clause folding retains fresh and shadowed leaf source occurrences"
    (for* ([conj (in-list '("left" "right"))]
           [disj (in-list '("left" "right"))]
           [delay (in-list '("relbody" "relcall" "disj"))])
      (assert-source-attribution!
       '((run* (q) (conde [(fresh (q) (== q 'private))])))
       "mini" (profile-jsexpr conj disj delay))))

  (test-case "micro keeps explicit conjunction, delay, repeated calls and primitive source spans"
    (assert-source-attribution!
     '((defrel (same x y)
         (Zzz (conj (== x y) (fresh (x) (conj (== x 'local) (=/= x y))))))
       (run* (q)
         (conj (same q q)
               (conj (Zzz (same q q)) (disj succeed (disj succeed fail))))))
     "micro"))

  (test-case "relation instantiation and fresh allocation preserve definition source identities"
    (for* ([conj (in-list '("left" "right"))]
           [disj (in-list '("left" "right"))]
           [delay (in-list '("relbody" "relcall" "disj"))])
      (define-values (cfg _markup _query)
        (parse-prog/canonical
         '((defrel (same x y) (fresh (x) (== x y)))
           (run* (q) (same q q) (same q q)))
         #:compile-profile (profile-jsexpr conj disj delay)))
      (match-define `(program ,definitions (commit (eval ,_ ,query-goal ,_))) cfg)
      (define calls (filter compiled-leaf? (compiled-goals query-goal)))
      (check-not-equal? (last (first calls)) (last (second calls)))
      (define original (strip-suspends (third (first definitions))))
      (for ([actual (in-list '(u:8 u:9))] [call (in-list calls)])
        (define copy
          (strip-suspends (instantiate-relation definitions `(r:same u:7 ,actual ,(last call)))))
        (check-equal? (map last (compiled-goals copy)) (map last (compiled-goals original)))
        (match-define `(∃ (x:x) (x:x =? ,(== actual) ,leaf-tag) ,fresh-tag) copy)
        (match-define `(eval ,_ ,allocated ,_)
          (allocate/s '(Owners) '(x:x) (third copy) fresh-tag
                      '(state () () () (label "s")) (list 'u:7 actual)))
        (check-equal? allocated `(u:0 =? ,actual ,leaf-tag))))))

(define/provide-test-suite TRANSPILER
  #:after (thunk (displayln "Finished running tests for transpiler."))

  SOURCE-MODES
  ASSOCIATIVITY
  COMPILE-PROFILES
  MICRO-SOURCE
  MICRO-RENDERING
  DISEQUALITY-TRANSLATION
  PRODUCTION-TRANSLATION
  SOURCE-ATTRIBUTION)

(module+ test
  (run-tests TRANSPILER))
