#lang racket

(require redex/reduction-semantics
         "./language.rkt")

(provide x-symbol/s?
         subst-term/s
         subst-goal/s
         extend-support-with-owners/s
         work-focus-prefix-support/s
         world-path-support/s
         fresh-u-atoms/s
         work/raw/s
         work/base/s
         frontier/raw/s
         frontier/base/s
         define-allocation/base/s
         allocate/base/s
         core-s-oracle-red
         raw-successors/s
         step-once/s)

(check-redundancy #t)

;; These host functions are narrow structural operations used by the direct
;; Redex allocation clause.  They do not dispatch among representations or
;; import any production semantics.
(define (x-symbol/s? datum)
  (and (symbol? datum)
       (regexp-match? #rx"^x:" (symbol->string datum))))

(define (subst-term/s t substitutions)
  (match t
    [(? x-symbol/s? x)
     (match (assoc x substitutions)
       [(list _ replacement) replacement]
       [#f x])]
    [`(,t_1 : ,t_2)
     `(,(subst-term/s t_1 substitutions)
       :
       ,(subst-term/s t_2 substitutions))]
    [_ t]))

(define (drop-shadowed/s binders substitutions)
  (match substitutions
    ['() '()]
    [(cons (and binding (list x _)) rest)
     (if (member x binders)
         (drop-shadowed/s binders rest)
         (cons binding (drop-shadowed/s binders rest)))]))

;; This substitution is simultaneous.  At a nested fresh, bindings for names
;; shadowed there are removed while substitutions for unrelated outer binders
;; continue through the nested body.
(define (subst-goal/s goal substitutions)
  (match goal
    [`(succeed ,tag) `(succeed ,tag)]
    [`(fail ,tag) `(fail ,tag)]
    [`(,t_1 =? ,t_2 ,tag)
     `(,(subst-term/s t_1 substitutions)
       =?
       ,(subst-term/s t_2 substitutions)
       ,tag)]
    [`(,t_1 != ,t_2 ,tag)
     `(,(subst-term/s t_1 substitutions)
       !=
       ,(subst-term/s t_2 substitutions)
       ,tag)]
    [`(,g_1 ∧ ,g_2 ,tag)
     `(,(subst-goal/s g_1 substitutions)
       ∧
       ,(subst-goal/s g_2 substitutions)
       ,tag)]
    [`(∃ ,binders ,body ,tag)
     `(∃ ,binders
          ,(subst-goal/s body
                         (drop-shadowed/s binders substitutions))
          ,tag)]
    [_
     (error 'subst-goal/s "unsupported core goal: ~e" goal)]))

(define (extend-support-with-owners/s owners [support '()])
  (match owners
    [`(Owners) support]
    [`(Owners (Owner ,intro ,_tag) ,owner_rest ...)
     (extend-support-with-owners/s
      `(Owners ,@owner_rest)
      (append support intro))]
    [_
     (error 'extend-support-with-owners/s
            "expected an Owners sequence, received ~e"
            owners)]))

(define (work-path-support/s work [support '()])
  (match work
    [`(Conj ,owners ,work_inner ,_goal)
     (work-path-support/s
      work_inner
      (extend-support-with-owners/s owners support))]
    [`(Work ,owners ,_goal ,_state)
     (extend-support-with-owners/s owners support)]
    [`(Returned ,owners ,_state)
     (extend-support-with-owners/s owners support)]
    [`(Dead ,owners)
     (extend-support-with-owners/s owners support)]
    [_
     (error 'work-path-support/s
            "expected core S work, received ~e"
            work)]))

;; Read only the Owner prefix encoded by an evaluation context.  Unlike a
;; whole-frontier occurrence scan, this datum contains the unique path from
;; More to the active hole and no focused work payload.
(define (redex-hole/s? datum)
  (equal? datum (term hole)))

(define (work-focus-prefix-support/s work-focus [support '()])
  (match work-focus
    [(? redex-hole/s?) support]
    [`(More ,work-path)
     (work-focus-prefix-support/s work-path support)]
    [`(Conj ,owners ,work-path_inner ,_goal)
     (work-focus-prefix-support/s
      work-path_inner
      (extend-support-with-owners/s owners support))]
    [_
     (error 'work-focus-prefix-support/s
            "expected a core S work-focus context, received ~e"
            work-focus)]))

;; There is exactly one active possible-world path in core.  Later branching
;; features invoke the same calculation independently on each selected world;
;; they must not concatenate incomparable siblings before calling it.
(define (world-path-support/s frontier)
  (match frontier
    [`(More ,work)
     (work-path-support/s work)]
    [`(Done ,owners)
     (extend-support-with-owners/s owners)]
    [`(Last ,owners (Answer ,answer_owners ,_state))
     (extend-support-with-owners/s
      answer_owners
      (extend-support-with-owners/s owners))]
    [_
     (error 'world-path-support/s
            "expected a core S frontier, received ~e"
            frontier)]))

(define (canonical-u/s n)
  (string->symbol (format "u:~a" n)))

;; Return the first count canonical u atoms absent from the incoming path
;; support.  The result order is binder order.
(define (fresh-u-atoms/s support count [candidate 0] [reversed-intro '()])
  (cond
    [(zero? count) (reverse reversed-intro)]
    [else
     (define u (canonical-u/s candidate))
     (if (or (member u support)
             (member u reversed-intro))
         (fresh-u-atoms/s support count (add1 candidate) reversed-intro)
         (fresh-u-atoms/s support
                          (sub1 count)
                          (add1 candidate)
                          (cons u reversed-intro)))]))

;; The ten work clauses are stated directly for this oracle.
(define work/raw/s
  (reduction-relation
   core-s-oracle-lang
   #:domain any
   [--> (Work owners (g_1 ∧ g_2 tag) (state sub dis trail tag_1))
        (Conj owners (Work (Owners) g_1 (state sub dis trail tag_1)) g_2)
        "expand-conjunction"]
   [--> (Work owners (succeed tag) σ)
        (Returned owners σ)
        "succeed"]
   [--> (Work owners (fail tag) σ)
        (Dead owners)
        "fail"]
   [--> (Conj owners_outer (Returned owners_inner σ) g)
        (Work (owners-append/s owners_outer owners_inner) g σ)
        "conj-return"]
   [--> (Conj owners_outer (Dead owners_inner) g)
        (Dead (owners-append/s owners_outer owners_inner))
        "conj-fail"]
   [--> (Work owners (t_1 =? t_2 tag) (state sub dis ((t_3 =? t_4 tag_1) ...) tag_2))
        (Returned owners (state sub_1 dis ((t_3 =? t_4 tag_1) ... (t_1 =? t_2 tag)) tag_2))
        (where sub_1 (unify/s (walk/s t_1 sub) (walk/s t_2 sub) sub))
        (where #f (invalid?/s sub_1 dis))
        "unify-success"]
   [--> (Work owners (t_1 =? t_2 tag) (state sub dis ((t_3 =? t_4 tag_1) ...) tag_2))
        (Dead owners)
        (where sub_1 (unify/s (walk/s t_1 sub) (walk/s t_2 sub) sub))
        (where #t (invalid?/s sub_1 dis))
        "unify-violates-disequality"]
   [--> (Work owners (t_1 =? t_2 tag) (state sub dis trail tag_2))
        (Dead owners)
        (where #f (unify/s (walk/s t_1 sub) (walk/s t_2 sub) sub))
        "unify-fail"]
   [--> (Work owners (t_1 != t_2 tag) (state sub dis trail tag_2))
        (Returned owners (state sub dis_1 trail tag_2))
        (where dis_1 ((t_1 t_2) ,@(term dis)))
        (where #f (invalid?/s sub dis_1))
        "disequality-success"]
   [--> (Work owners (t_1 != t_2 tag) (state sub dis trail tag_2))
        (Dead owners)
        (where dis_1 ((t_1 t_2) ,@(term dis)))
        (where #t (invalid?/s sub dis_1))
        "disequality-fail"]))

(define frontier/raw/s
  (reduction-relation
   core-s-oracle-lang
   #:domain any
   [--> (More (Returned owners σ))
        (Last owners (Answer (Owners) σ))
        "finish-success"]
   [--> (More (Dead owners))
        (Done owners)
        "finish-failure"]))

;; Freshness is computed from precisely the Owner groups on the active world
;; path.  Goal/state occurrences and unreachable sibling worlds are not used
;; as an allocation registry; well-formedness establishes their coverage by
;; the path's introductions.  The explicit operation arguments are the
;; extension seams: a feature language can instantiate this same equation with
;; its own recursively extended goal traversal and WorkFocus-prefix view,
;; without replacing the rule.
(define-syntax-rule
  (define-allocation/base/s relation-id
                            language-id
                            substitute-goal-id
                            work-focus-prefix-support-id)
  (define relation-id
    (reduction-relation
     language-id
     #:domain F
     [--> (in-hole WorkFocus (Work owners (∃ (x_bound (... ...)) g tag) σ))
          (in-hole WorkFocus (Work (owners-append/s owners (Owners (Owner (u_new (... ...)) tag))) g_new σ))
          (where (u_new (... ...))
                 ,(fresh-u-atoms/s
                   (extend-support-with-owners/s
                    (term owners)
                    (work-focus-prefix-support-id (term WorkFocus)))
                   (length (term (x_bound (... ...))))))
          (where g_new
                 ,(substitute-goal-id
                   (term g)
                   (term ((x_bound u_new) (... ...)))))
          "allocate-fresh"])))

(define-allocation/base/s
  allocate/base/s
  core-s-oracle-lang
  subst-goal/s
  work-focus-prefix-support/s)

(define work/base/s
  (context-closure work/raw/s core-s-oracle-lang WorkFocus))

(define frontier/base/s
  (context-closure frontier/raw/s core-s-oracle-lang SpineContext))

(define core-s-oracle-red
  (extend-reduction-relation
   (union-reduction-relations
    work/base/s
    frontier/base/s
    allocate/base/s)
   core-s-oracle-lang
   #:domain F))

(define (raw-successors/s frontier)
  (for/list ([named-step
              (in-list
               (apply-reduction-relation/tag-with-names
                core-s-oracle-red
                frontier))])
    (match-define (list name target) named-step)
    (list (string->symbol (~a name)) target)))

(define (step-once/s frontier)
  (define named-next* (raw-successors/s frontier))
  (match named-next*
    ['() '()]
    [(list only-step) (list only-step)]
    [_
     (error 'step-once/s
            "nondeterministic successors for ~e: ~e"
            frontier
            named-next*)]))
