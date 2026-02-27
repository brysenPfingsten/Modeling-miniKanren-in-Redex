#lang racket
(require rackunit
         redex/reduction-semantics
         "core-definitions.rkt")

(check-redundancy #t)

(provide wf-goal?
		 wf-tree?
		 wf-term?
		 wf-state?
         wf-sub/wf+equiv-trail?
         wf-sub?
		 wf-config?)

(module+ test
  (require rackunit)
  (default-language Core))

(define-judgment-form
  Core
  #:contract (lvar-member? u c)
  #:mode (lvar-member? I I)

  [--------"lvar member"
   (lvar-member? u (u_1 ... u u_2 ...))]
)

(module+ test
  (check-true (judgment-holds (lvar-member? u:0 (u:0))))
  (check-true (judgment-holds (lvar-member? u:0 (u:1 u:0))))
  (check-false (judgment-holds (lvar-member? u:7 (u:0))))
  (check-true (judgment-holds (lvar-member? u:1 (u:2 u:1 u:0))))
)

(define-judgment-form
  Core
  #:contract (lvars-subset? (u ...) (u ...))
  #:mode (lvars-subset? I I)

  [------------------- "empty ⊆ anything"
   (lvars-subset? () c)]

  [(lvar-member? u c_2)
   (lvars-subset? (u_rest ...) c_2)
   ------------------- "cons ⊆"
   (lvars-subset? (u u_rest ...) c_2)])


(define-judgment-form
  Core
  #:contract (wf-term? t (x ...) c)
  #:mode (wf-term? I I I)

  [(lvar-member? u c)
   -------------- "lv in extant lvs"
   (wf-term? u (x ...) c)]

  [-------------- "primitive terms are wf and valid"
   (wf-term? pt (x ...) c)]

  [(wf-term? t_2 (x ...) c)
   (wf-term? t_1 (x ...) c)
   -------------- "pairs wf when constituents wf"
   (wf-term? (t_1 : t_2) (x ...) c)]

  [-------------- "lexical var is in lv bindings"
   (wf-term? x_2 (x_1 ... x_2 x_3 ...) c)])

(module+ test
  (check-true (judgment-holds (wf-term? (sym "a") () ())))
  (check-true (judgment-holds (wf-term? u:0 () (u:0))))
  (check-true (judgment-holds (wf-term? u:1 () (u:0 u:1))))
  (check-false (judgment-holds (wf-term? u:3 () (u:0 u:1))))
  ;; lexical variable must be in the binder list
  (check-true  (judgment-holds (wf-term? x:0 (x:0) (u:5))))
  (check-false (judgment-holds (wf-term? x:0 () (u:5))))
)

(define-judgment-form
  Core
  #:contract (wf-sub? sub c)
  #:mode (wf-sub? I I)

  [(wf-term? t () c) ...
   (lvar-member? u c) ...
   #;(triangular? ([u t] ...))
   ------------------"sub closed under c w/no lexical vars"
   (wf-sub? ([u t] ...) c)])

(module+ test
  (check-true  (judgment-holds (wf-sub? ((u:0 (sym "x"))) (u:0))))
  (check-false (judgment-holds (wf-sub? ((u:1 (sym "x"))) (u:0))))
  ;; two bindings ok
  (check-true  (judgment-holds (wf-sub? ((u:0 (sym "x")) (u:2 (sym "y")))
                                        (u:0 u:2))))
)

(define-judgment-form
  Core
  #:contract (wf-goal? g ((r (x ...)) ...) (x_1 ...) c)
  #:mode (wf-goal? I I I I)

  [------------------ "trivial success wf"
   (wf-goal? (succeed tag) ((r (x ...)) ...) (x_1 ...) c)]

  [(where (u_old ...) c)
   (where (u_new ...) (fresh-lvars (x_1 ...) c))
   (wf-goal? g ((r (x ...)) ...) (x_1 ... x_2 ...) (u_new ... u_old ...))
   ------------------- "fresh-wf"
   (wf-goal? (∃ (x_1 ...) g tag) ((r (x ...)) ...) (x_2 ...) c)]

  [(wf-goal? g_1 ((r (x ...)) ...) (x_1 ...) c)
   (wf-goal? g_2 ((r (x ...)) ...) (x_1 ...) c)
   ---------- "conj-wf"
   (wf-goal? (g_1 ∧ g_2 tag) ((r (x ...)) ...) (x_1 ...) c)]

  [(wf-term? t_1 (x_1 ...) c)
   (wf-term? t_2 (x_1 ...) c)
   ---------- "==-wf"
   (wf-goal? (t_1 =? t_2 tag) ((r (x ...)) ...) (x_1 ...) c)]

  )

(module+ test
  ;; succeed
  (check-true (judgment-holds (wf-goal? (succeed (label "fish")) () () ())))

  ;; equality with only lvs present in c
  (check-true (judgment-holds
               (wf-goal? (u:0 =? (sym "a") (label "t"))
                         ()
                         ()
                         (u:0))))

  ;; conjunction
  (check-true (judgment-holds
               (wf-goal? ((u:0 =? (sym "a") (label "t1"))
                          ∧ (u:1 =? (sym "b") (label "t2")) (label "∧"))
                         ()
                         ()
                         (u:0 u:1))))

  ;; ∃ adds fresh u's to c via add-vars-not-in
  (check-true
    (judgment-holds
      (wf-goal? (u:0 =? (sym "a") (label "t"))
                ()
                (x:0 x:1)
                (u:2 u:1 u:0))))

  ;; ∃ adds fresh u's to c via add-vars-not-in
  (check-true
    (judgment-holds
      (wf-goal? (∃ (x:0 x:1)
                  (u:0 =? (sym "a") (label "t")) (label "fresh"))
                ()
                ()
                (u:0))))
)

;; Given a list of used symbols, produce a fresh one
(define-metafunction Core
  ;; Takes a list of symbols, returns a fresh symbol
  fresh-lv : (u ...) -> u
  [(fresh-lv (u ...)) ,(variable-not-in (cons 'u: (term (u  ...))) 'u:)])


;; redex's variables-not-in uses the vars list themselves as the
;; prefixes, which doesn't work with our use case.
(define-metafunction Core
  fresh-lvars : (x ...) c -> c
  [(fresh-lvars (x ...) c)
    ,(for/fold ([fv* '()])
               ([_ (in-list (term (x ...)))])
       (define fv (variable-not-in (cons 'u: (append fv* (term c))) 'u:))
       (cons fv fv*))])

(module+ test
  (check-equal?
    (term (fresh-lvars (x:0 x:1 x:2) (u:1 u:7 u:3)))
    '(u:5 u:4 u:2)))

(define-judgment-form
  Core
  #:contract (wf-trail-unify*s-to-sub (eq ...) c sub sub)
  #:mode (wf-trail-unify*s-to-sub I I I I)

  [-------------------"trail is empty, acc is our sub"
   (wf-trail-unify*s-to-sub () c sub sub)]

  ;; grammar makes subst's u's distinct; if each is in c, |subst| < c
  [(where sub_acc2 (unify (walk t_1 sub_acc) (walk t_2 sub_acc) sub_acc))
   (wf-term? t_1 () c)
   (wf-term? t_2 () c)
   (wf-trail-unify*s-to-sub (eq ...) c sub_acc2 sub)
   -------------------"this pair is well formed and unify"
   (wf-trail-unify*s-to-sub ((t_1 =? t_2 tag) eq ...) c sub_acc sub)]

)

(module+ test
  (check-false (judgment-holds (wf-trail-unify*s-to-sub () (u:2 u:1 u:0) ((u:0 u:2) (u:1 u:0)) ((u:1 u:0)))))
  (check-false (judgment-holds (wf-trail-unify*s-to-sub () (u:2 u:1 u:0) ((u:1 u:0)) ((u:0 u:2) (u:1 u:0)))))
)



(define-judgment-form
  Core
  #:contract (wf-sub/wf+equiv-trail? sub c trail)
  #:mode (wf-sub/wf+equiv-trail? I I I)

  ;; grammar makes subst's u's distinct; if each is in c, |subst| < c
  [(wf-sub? sub c)
   (wf-trail-unify*s-to-sub (eq ...) c () sub)
   -------------------"goal w/ sub wf"
   (wf-sub/wf+equiv-trail? sub c (eq ...))]

)

(define-judgment-form
  Core
  #:contract (wf-state? σ)
  #:mode (wf-state? I)

  [(wf-sub/wf+equiv-trail? sub c trail)
   ----------------------- "state wf"
   (wf-state? (state sub c trail tag))])

(define-judgment-form
  Core
  #:contract (wf-tree? s ((r d) ...) c)
  #:mode (wf-tree? I I I)

  [-------------------"empty tree is wf"
   (wf-tree? (empty-tree) ((r d) ...) c)]

  [(lvars-subset? c c_i)
   (wf-sub/wf+equiv-trail? sub c_i trail)
   -------------------"single answer/state wf"
   (wf-tree? (⊤ (state sub c_i trail tag)) ((r d) ...) c)]

  [(lvars-subset? c c_i)
   (wf-goal? g ((r d) ...) () c_i)
   (wf-sub/wf+equiv-trail? sub c_i trail)
   -------------------"goal/state wf"
   (wf-tree? (g (state sub c_i trail tag)) ((r d) ...) c)]

  [(lvars-subset? c c_i)
   (wf-tree? s ((r d) ...) c_i)
   (wf-goal? g ((r d) ...) () c_i)
   -------------------"conj wf"
   (wf-tree? (s × g c_i) ((r d) ...) c)])

(define-judgment-form
  Core
  #:contract (wf-config? config)
  #:mode (wf-config? I)
  [(wf-state? σ) ...
   (wf-tree? s ((r d) ...) ())
   (wf-goal? g ((r d) ...) d ()) ...
   ----------------------- "program-wf"
   (wf-config? (((r d g) ...) (σ ...) s))]
  )

  #;[(wf-tree? s ((r (x ...)) ...))
   -------------------"partial tree wf"
   (wf-tree? (∂ s _) ((r (x ...)) ...))] ;; TODO: wf-state-judgement?

  #;[(wf-tree? s_1 ((r (x ...)) ...))
   (wf-tree? s_2 ((r (x ...)) ...))
   -------------------"left disj wf"
   (wf-tree? (s_1 <-+ s_2) ((r (x ...)) ...))]

  #;[(wf-tree? s_1 ((r (x ...)) ...))
   (wf-tree? s_2 ((r (x ...)) ...))
   -------------------"right disj wf"
   (wf-tree? (s_1 +-> s_2) ((r (x ...)) ...))]



;; (define-judgment-form
;;   Core
;;   #:contract (wf-trail? trail c)
;;   #:mode (wf-trail? I I)

;;   [
;;    ------------------ "empty trail is wf"
;;    (wf-trail? () c)]

;;   [(wf-term? t_1 () c)
;;    (wf-term? t_2 () c)
;;    (wf-trail? ((t_3 =? t_4 o) ...) c)
;;    ------------------ "trail is wf"
;;   (wf-trail? ((t_1 =? t_2 _) (t_3 =? t_4 o) ...) c)])

  ;; [(wf-goal? g_1 ((r (x ...)) ...) (x_1 ...) c)
  ;;  (wf-goal? g_2 ((r (x ...)) ...) (x_1 ...) c)
  ;;  ---------- "disj-wf"
  ;;  (wf-goal? (g_1 ∨ g_2 _) ((r (x ...)) ...) (x_1 ...) c)]

  ;; [(same-length? (t ...) (x_i ...))
  ;;  (wf-term? t (x_k ...) c) ...
  ;;  ---------- "relcall-wf"
  ;;  (wf-goal? (r_i t ... _) ((r_1 (x_1 ...)) ... (r_i (x_i ...)) (r_j (x_j ...)) ...) (x_k ...) c)]

  #;[(wf-tree? s ((r (x ...)) ...))
   -------------------"delay wf"
   (wf-tree? (delay s) ((r (x ...)) ...))]

  #;[(wf-tree? s ((r (x ...)) ...))
   -------------------"proceed wf"
   (wf-tree? (proceed s) ((r (x ...)) ...))]



(module+ test
  ;; two-step trail; final σ must be exactly as unify builds it (new bindings consed in front)
  (check-true
   (judgment-holds
    (wf-trail-unify*s-to-sub
     ((u:0 =? (sym "a") (label "t1"))
      ((u:1 : u:0) =? ((sym "b") : (sym "a")) (label "t2")))
     (u:0 u:1)
     ()
     ((u:1 (sym "b")) (u:0 (sym "a"))))))

  (check-true
   (judgment-holds
    (wf-sub/wf+equiv-trail?
     ((u:1 (sym "b")) (u:0 (sym "a")))
     (u:0 u:1)
     ((u:0 =? (sym "a") (label "t1"))
      ((u:1 : u:0) =? ((sym "b") : (sym "a")) (label "t2"))))))
)


(module+ test
  (check-false
   (judgment-holds
    (wf-state? (state ((u:1 (sym "b")) (u:0 (sym "a")))
                      (u:0 u:1)
                      ((u:0 =? (sym "a") (label "t1")))
                      (label "σ")))))

  (check-false
   (judgment-holds
    (wf-state? (state ((u:1 (sym "b")) (u:0 (sym "a")))
                      (u:0 u:1)
                      ((u:1 =? (sym "b") (label "t2"))
                       (u:0 =? (sym "a") (label "t1")))
                      (label "σ")))))

  ;; empty tree
  (check-true (judgment-holds (wf-tree? (empty-tree) () ())))
  ;; goal/state node
  (check-true
   (judgment-holds
    (wf-tree?
      ((u:0 =? (sym "a") (label "t"))
       (state ((u:0 (sym "a")))
              (u:0)
              ((u:0 =? (sym "a") (label "t1")))
              (label "σ")))
      ()
	  (u:0))))
  ;; conjunction
  (check-true
   (judgment-holds
    (wf-tree?
      (((u:0 =? (sym "a") (label "t"))
       (state ((u:0 (sym "a")))
              (u:0)
              ((u:0 =? (sym "a") (label "t1")))
              (label "σ")))
       ×
       (succeed (label "fish"))
	   ())
      ()
	  ())))

  ;; whole program: no states and empty relations
  (check-true
   (judgment-holds
    (wf-config? (() () (empty-tree)))))

  ;; whole program: one state and empty relations
  (check-true
   (judgment-holds
    (wf-config?
     (()  ; Γ
      ((state ((u:0 (sym "a"))) (u:0) (((sym "a") =? u:0 (label "g1"))) (label "σ"))) ; ans*
      (empty-tree)))))                                ; s
)

(module+ test
  (require rackunit
           redex/reduction-semantics
           racket/list
           (prefix-in h: "../tests/helpers.rkt"))

  ;; Randomized test tuning constants.
  ;; Edit these values directly when you want different pressure/coverage.
  (define JUDGMENT-PROP-ATTEMPTS 200)
  (define JUDGMENT-PROP-SIZE 8)
  (define JUDGMENT-PROP-SEED 424242)
  (define JUDGMENT-U-POOL-SIZE 24)
  (define JUDGMENT-C-MAX 4)
  (define JUDGMENT-MIN-UNIFY-SUCCESSES 1)
  (define JUDGMENT-MIN-UNIFY-FAILURES 1)
  (define JUDGMENT-MIN-PAIR-CASES 1)

  (define JUDGMENT-RNG (h:make-seeded-rng JUDGMENT-PROP-SEED))

  (define (jrandom n)
    (h:rng-random JUDGMENT-RNG n))

  (define (j-generate-t)
    (parameterize ([current-pseudo-random-generator JUDGMENT-RNG])
      (generate-term Core t JUDGMENT-PROP-SIZE)))

  (define (j-generate-sub)
    (parameterize ([current-pseudo-random-generator JUDGMENT-RNG])
      (generate-term Core sub JUDGMENT-PROP-SIZE)))

  (displayln
   (format "[core-judgment-forms] randomized checks attempts=~a size=~a seed=~a"
           JUDGMENT-PROP-ATTEMPTS
           JUDGMENT-PROP-SIZE
           JUDGMENT-PROP-SEED))

  ;; Pool size bounds generated test-data diversity only; it does not bound
  ;; the semantic space of logic variables used by the language.
  (define U-POOL
    (for/list ([n (in-range 0 JUDGMENT-U-POOL-SIZE)])
      (string->symbol (format "u:~a" n))))

  (check-true (positive? JUDGMENT-U-POOL-SIZE)
              "JUDGMENT-U-POOL-SIZE must be >= 1.")
  (check-true (positive? JUDGMENT-C-MAX)
              "JUDGMENT-C-MAX must be >= 1.")

  ;; Constructively build wf terms with respect to c (no lexical vars).
  (define (gen-wf-term c depth)
    (define choices
      (append '(primitive)
              (if (null? c) '() '(logic-var))
              (if (zero? depth) '() '(pair))))
    (case (list-ref choices (jrandom (length choices)))
      [(primitive) (h:gen-primitive/rng JUDGMENT-RNG)]
      [(logic-var) (list-ref c (jrandom (length c)))]
      [(pair) `(,(gen-wf-term c (sub1 depth)) : ,(gen-wf-term c (sub1 depth)))]))

  ;; Returns a sample (list t1 t2 sub c trail tag1 tag2) that always satisfies
  ;; the wf-tree antecedent used by the randomized unify checks.
  (define (generate-wf-eq-sample)
    (define c-limit (min JUDGMENT-C-MAX (length U-POOL)))
    (define c-size (add1 (jrandom c-limit)))
    (define c (h:random-distinct/rng JUDGMENT-RNG U-POOL c-size))
    (define depth (max 1 (min 4 JUDGMENT-PROP-SIZE)))
    (define t_1 (gen-wf-term c depth))
    ;; Bias half the time to guaranteed unification success.
    (define t_2 (if (zero? (jrandom 2)) t_1 (gen-wf-term c depth)))
    (list t_1 t_2 (term ()) c (term ()) (term (label "t1")) (term (label "t2"))))

  ;; Deterministic must-hit samples keep minimum-threshold checks stable.
  (define (forced-success-sample)
    (list (term (sym "forced-s"))
          (term (sym "forced-s"))
          (term ())
          (term ())
          (term ())
          (term (label "forced"))
          (term (label "forced"))))

  (define (forced-failure-sample)
    (list (term (sym "forced-left"))
          (term (sym "forced-right"))
          (term ())
          (term ())
          (term ())
          (term (label "forced"))
          (term (label "forced"))))

  (define (forced-pair-sample)
    (list (term ((sym "forced-a") : empty))
          (term ((sym "forced-a") : empty))
          (term ())
          (term ())
          (term ())
          (term (label "forced"))
          (term (label "forced"))))

  ;; walk is idempotent
  (for ([_ (in-range JUDGMENT-PROP-ATTEMPTS)])
    (define t* (j-generate-t))
    (define sub* (j-generate-sub))
    (check-equal? (term (walk (walk ,t* ,sub*) ,sub*))
                  (term (walk ,t* ,sub*))))

  ;; If unify succeeds on wf inputs, the results walk to the same thing.
  ;; Also check triangular/occurs-free invariants on successful outputs.
  (define wf-hits 0)
  (define unify-successes 0)
  (define unify-failures 0)
  (define pair-cases 0)
  (define max-c-size-seen 0)

  (define (vars-in t)
    (cond
      [(symbol? t) (list t)]
      [(pair? t)   (append (vars-in (car t)) (vars-in (cdr t)))]
      [else        '()]))

  (define (triangular? pairs)
    (define dom (map first pairs))
    (define adj
      (for/hash ([(u t*) (in-dict pairs)])
        (values u
                (filter (lambda (v) (member v dom))
                        (remove-duplicates (vars-in (car t*)))))))
    (define visiting (make-hash))
    (define visited (make-hash))
    (define (visit u)
      (cond
        [(hash-ref visited u #f) #t]
        [(hash-ref visiting u #f) #f]
        [else
         (hash-set! visiting u #t)
         (define ok
           (for/and ([v (in-list (hash-ref adj u '()))])
             (visit v)))
         (hash-remove! visiting u)
         (when ok (hash-set! visited u #t))
         ok]))
    (for/and ([u dom]) (visit u)))

  (define (occurs-free? pairs)
    (for/and ([(u t*) (in-dict pairs)])
      (not (judgment-holds (occurs? ,u ,(car t*) ,pairs)))))

  ;; Full walk over pair terms for testing unify equalization.
  ;; The core walk metafunction is intentionally shallow.
  (define (walk* t sub)
    (define w (term (walk ,t ,sub)))
    (match w
      [`(,a : ,d) `(,(walk* a sub) : ,(walk* d sub))]
      [_ w]))

  (define (pair-term? t)
    (match t
      [`(,_ : ,_) #t]
      [_ #f]))

  (for ([i (in-range JUDGMENT-PROP-ATTEMPTS)])
    (define sample
      (cond
        [(zero? i) (forced-success-sample)]
        [(= i 1) (forced-failure-sample)]
        [(= i 2) (forced-pair-sample)]
        [else (generate-wf-eq-sample)]))
    (define t_1 (first sample))
    (define t_2 (second sample))
    (define sub (third sample))
    (define c (fourth sample))
    (define trail (fifth sample))
    (define tag_1 (sixth sample))
    (define tag_2 (seventh sample))
    (set! max-c-size-seen (max max-c-size-seen (length c)))
    (when (or (pair-term? t_1) (pair-term? t_2))
      (set! pair-cases (add1 pair-cases)))
    (check-true
     (judgment-holds
      (wf-tree? ((,t_1 =? ,t_2 ,tag_1)
                 (state ,sub ,c ,trail ,tag_2))
                ()
                ())))
    (set! wf-hits (add1 wf-hits))
    (define sub^ (term (unify (walk ,t_1 ,sub) (walk ,t_2 ,sub) ,sub)))
    (unless (equal? sub^ (term #f))
      (set! unify-successes (add1 unify-successes))
      (check-true (equal? (walk* t_1 sub^)
                          (walk* t_2 sub^))
                  "Unify result does not equalize walked terms.")
      (check-true (triangular? sub^)
                  "Unify result is not triangular.")
      (check-true (occurs-free? sub^)
                  "Unify result violates occurs-check closure."))
    (when (equal? sub^ (term #f))
      (set! unify-failures (add1 unify-failures))))

  (displayln
   (format "[core-judgment-forms] wf-hits=~a unify-successes=~a unify-failures=~a pair-cases=~a max-c-size=~a seed=~a"
           wf-hits
           unify-successes
           unify-failures
           pair-cases
           max-c-size-seen
           JUDGMENT-PROP-SEED))

  (check-true (> wf-hits 0)
              "Unify properties had zero well-formed antecedent hits; test would be vacuous.")
  (check-true (>= unify-successes JUDGMENT-MIN-UNIFY-SUCCESSES)
              "Unify properties had too few successful unifications.")
  (check-true (>= unify-failures JUDGMENT-MIN-UNIFY-FAILURES)
              "Unify properties had too few failing unifications.")
  (check-true (>= pair-cases JUDGMENT-MIN-PAIR-CASES)
              "Unify properties had too few pair-term cases.")

)
