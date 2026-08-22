#lang racket

(require redex/reduction-semantics
         "../../../framework/core-source-schema.rkt")

(provide core-s-representation-strategy
         generated-core-s-lang
         generated-core-s-red
         raw-successors/generated/s
         branch-copy/generated/s
         wf-core/generated/s?
         live-supply/generated/s
         failure-summary/generated/s
         address/generated/s
         q-export/generated/s
         q-rebuild/generated/s
         q-focus-export/generated/s
         q-focus-rebuild/generated/s
         generated-core-s-source)

(check-redundancy #t)

;; The selected S representation retains grouped, tagged Owner provenance.
;; Cumulative allocated-name support is derived from the active world path;
;; it is not cached in the logical state or scanned from a whole frontier.
(define-core-representation-strategy core-s-representation-strategy
  #:variable
  [#:runtime-variable-production (variable-prefix u:)
   #:productions ()
   #:definitions
   ((define (owners->support/generated/s owners [support '()])
      (match owners
        [`(Owners) support]
        [`(Owners (Owner ,intro ,_tag) ,owner-rest ...)
         (owners->support/generated/s
          `(Owners ,@owner-rest)
          (append support intro))]
        [_
         (error 'owners->support/generated/s
                "expected Owners, received ~e"
                owners)]))
    (define (work-focus-prefix-support/generated/s work-focus
                                                   [support '()])
      (match work-focus
        [(? (lambda (datum) (equal? datum (term hole)))) support]
        [`(More ,work-path)
         (work-focus-prefix-support/generated/s work-path support)]
        [`(Conj ,owners ,work-path ,_goal)
         (work-focus-prefix-support/generated/s
          work-path
          (owners->support/generated/s owners support))]
        [_
         (error 'work-focus-prefix-support/generated/s
                "expected an S WorkFocus, received ~e"
                work-focus)]))
    (define (canonical-u/generated/s index)
      (string->symbol (format "u:~a" index)))
    (define (fresh-us/generated/s support count
                                  [candidate 0]
                                  [reversed-intro '()])
      (cond
        [(zero? count) (reverse reversed-intro)]
        [else
         (define u (canonical-u/generated/s candidate))
         (if (or (member u support)
                 (member u reversed-intro))
             (fresh-us/generated/s
              support
              count
              (add1 candidate)
              reversed-intro)
             (fresh-us/generated/s
              support
              (sub1 count)
              (add1 candidate)
              (cons u reversed-intro)))]))
    (define-metafunction LANG
      owners-append/generated/s : supply supply -> supply
      [(owners-append/generated/s
        (Owners owner_outer ...)
        (Owners owner_inner ...))
       (Owners owner_outer ... owner_inner ...)]))
   #:walk-hook generated-structural
   #:unify-hook generated-first-order
   #:invalid-hook generated-store-check
   #:lexical-substitution-hook generated-binder-local
   #:allocation
   [#:source
    (in-hole
     WorkFocus
     (Work supply (∃ (x_bound ...) g tag) sigma))
    #:target
    (in-hole
     WorkFocus
     (Work
      (owners-append/generated/s
       supply
       (Owners (Owner (rv_new ...) tag)))
      g_new
      sigma))
    #:premises
    ((where (rv_new ...)
            ,(fresh-us/generated/s
              (owners->support/generated/s
               (term supply)
               (work-focus-prefix-support/generated/s
                (term WorkFocus)))
              (length (term (x_bound ...)))))
     (where g_new
            ,(SUBST-GOAL-HOOK
              (term g)
              (term ((x_bound rv_new) ...)))))]
   #:addressing-hook address/generated/s]
  #:supply/provenance
  [#:productions
   ([intro (rv_!_ ...)]
    [owner (Owner intro tag)]
    [supply (Owners owner ...)])
   #:carriers
   [#:state (state sub dis trail tag)
    #:answer (Answer supply sigma)
    #:returned (Returned supply sigma)
    #:work (Work supply g sigma)
    #:dead (Dead supply)
    #:conj (Conj supply W g)
    #:last (Last supply A)
    #:done (Done supply)
    #:more (More W)]
   #:empty-supply (Owners)
   #:conjunction-focus-supply (Owners)
   #:branch-copy-supply supply
   #:join-return-supply
   (owners-append/generated/s supply_outer supply_inner)
   #:join-failure-supply
   (owners-append/generated/s supply_outer supply_inner)
   #:terminal-answer-supply (Owners)
   #:live-supply-hook live-supply/generated/s
   #:failure-summary-hook failure-summary/generated/s
   #:definitions ()
   #:well-formedness
   [#:definitions
    ((define (u-symbol?/generated/s datum)
       (and (symbol? datum)
            (regexp-match? #rx"^u:" (symbol->string datum))))
     (define (runtime-us/generated/s datum [acc '()])
       (match datum
         ['() acc]
         [(? u-symbol?/generated/s u)
          (if (member u acc) acc (cons u acc))]
         [(cons a d)
          (runtime-us/generated/s
           a
           (runtime-us/generated/s d acc))]
         [_ acc]))
     (define (sub-dependencies/generated/s u substitution)
       (match (assoc u substitution)
         [(list _ term)
          (define domain (map first substitution))
          (filter (lambda (dependency) (member dependency domain))
                  (runtime-us/generated/s term))]
         [#f '()]))
     (define (acyclic-from/generated/s u substitution [path '()])
       (and
        (not (member u path))
        (for/and ([dependency
                   (in-list
                    (sub-dependencies/generated/s u substitution))])
          (acyclic-from/generated/s
           dependency
           substitution
           (cons u path)))))
     (define (substitution-acyclic?/generated/s substitution)
       (for/and ([u (in-list (map first substitution))])
         (acyclic-from/generated/s u substitution)))
     (define (valid-owners?/generated/s owners)
       (with-handlers ([exn:fail? (lambda (_exception) #f)])
         (define support (owners->support/generated/s owners))
         (and (andmap u-symbol?/generated/s support)
              (= (length support)
                 (length (remove-duplicates support))))))
     (define (valid-owner-extension?/generated/s prefix local)
       (and (valid-owners?/generated/s prefix)
            (valid-owners?/generated/s local)
            (for/and ([u
                       (in-list
                        (owners->support/generated/s local))])
              (not (member u (owners->support/generated/s prefix))))))
     (define-judgment-form
       LANG
       #:contract (allocated/generated/s? rv supply)
       #:mode (allocated/generated/s? I I)
       [(where #t
               ,(and
                 (member (term rv)
                         (owners->support/generated/s (term supply)))
                 #t))
        -------------------------------------------------- "allocated Owner variable/s"
        (allocated/generated/s? rv supply)])
     (define-judgment-form
       LANG
       #:contract (valid-supply/generated/s? supply)
       #:mode (valid-supply/generated/s? I)
       [(where #t ,(valid-owners?/generated/s (term supply)))
        -------------------------------------------------- "valid Owner path/s"
        (valid-supply/generated/s? supply)])
     (define-judgment-form
       LANG
       #:contract (extend-supply/generated/s supply supply supply)
       #:mode (extend-supply/generated/s I I O)
       [(where #t
               ,(valid-owner-extension?/generated/s
                 (term supply_in)
                 (term supply_local)))
        (where supply_out
               (owners-append/generated/s supply_in supply_local))
        -------------------------------------------------- "extend Owner path/s"
        (extend-supply/generated/s
         supply_in
         supply_local
         supply_out)])
     (define-metafunction LANG
       acyclic-substitution/generated/s? : sub -> boolean
       [(acyclic-substitution/generated/s? sub)
        ,(substitution-acyclic?/generated/s (term sub))]))
    #:allocated-hook allocated/generated/s?
    #:valid-supply-hook valid-supply/generated/s?
    #:extend-supply-hook extend-supply/generated/s
    #:acyclic-substitution-hook acyclic-substitution/generated/s?
    #:state-supply-premises ()
    #:frame-prefix-premises
    ((EXTEND-SUPPLY-HOOK supply_in supply_local supply_frame))
    #:conjunction-goal-supply-premises
    ((where supply_goal supply_frame))
    #:terminal-prefix-premises
    ((EXTEND-SUPPLY-HOOK (Owners) supply_local supply_prefix))
    #:root wf-core/generated/s?]
   #:q-map
   [#:definitions
    ((define (address/generated/s value _support) value)
     (define (state->q/generated/s state support)
       (match state
         [`(state ,sub ,dis ,trail ,state-tag)
          `(q-state ,support ,sub ,dis ,trail ,state-tag)]
         [_
          (error 'q-export/generated/s
                 "expected S state, received ~e"
                 state)]))
     (define (work->q/generated/s work [support '()])
       (match work
         [`(Work ,owners ,goal ,state)
          (define support-here
            (owners->support/generated/s owners support))
          `(q-work
            ,owners
            ,goal
            ,(state->q/generated/s state support-here))]
         [`(Returned ,owners ,state)
          (define support-here
            (owners->support/generated/s owners support))
          `(q-returned
            ,owners
            ,(state->q/generated/s state support-here))]
         [`(Dead ,owners)
          `(q-dead
            ,owners
            ,(owners->support/generated/s owners support))]
         [`(Conj ,owners ,inner ,goal)
          (define support-here
            (owners->support/generated/s owners support))
          `(q-conj
            ,owners
            ,(work->q/generated/s inner support-here)
            ,goal)]
         [_
          (error 'q-export/generated/s
                 "expected S work, received ~e"
                 work)]))
     (define (q-export/generated/s frontier)
       (match frontier
         [`(More ,work)
          `(q-more ,(work->q/generated/s work))]
         [`(Done ,owners)
          `(q-done
            ,owners
            ,(owners->support/generated/s owners))]
         [`(Last ,owners (Answer ,answer-owners ,state))
          (define prefix
            (owners->support/generated/s owners))
          `(q-last
            ,owners
            (q-answer
             ,answer-owners
             ,(state->q/generated/s
               state
               (owners->support/generated/s
                answer-owners
                prefix))))]
         [_
          (error 'q-export/generated/s
                 "expected S frontier, received ~e"
                 frontier)]))
     (define (owners-view/generated/s who value)
       (match value
         [`(Owners . ,_) value]
         [_
          (error who
                 "neutral view has no S Owner provenance: ~e"
                 value)]))
     (define (q-state->s/generated/s q-state)
       (match q-state
         [`(q-state ,_support ,sub ,dis ,trail ,state-tag)
          `(state ,sub ,dis ,trail ,state-tag)]
         [_
          (error 'q-rebuild/generated/s
                 "expected neutral state, received ~e"
                 q-state)]))
     (define (q-work->s/generated/s q-work)
       (match q-work
         [`(q-work ,owners ,goal ,q-state)
          `(Work
            ,(owners-view/generated/s 'q-rebuild/generated/s owners)
            ,goal
            ,(q-state->s/generated/s q-state))]
         [`(q-returned ,owners ,q-state)
          `(Returned
            ,(owners-view/generated/s 'q-rebuild/generated/s owners)
            ,(q-state->s/generated/s q-state))]
         [`(q-dead ,owners ,_support)
          `(Dead
            ,(owners-view/generated/s 'q-rebuild/generated/s owners))]
         [`(q-conj ,owners ,inner ,goal)
          `(Conj
            ,(owners-view/generated/s 'q-rebuild/generated/s owners)
            ,(q-work->s/generated/s inner)
            ,goal)]
         [_
          (error 'q-rebuild/generated/s
                 "expected neutral work, received ~e"
                 q-work)]))
     (define (q-rebuild/generated/s neutral)
       (match neutral
         [`(q-more ,q-work)
          `(More ,(q-work->s/generated/s q-work))]
         [`(q-done ,owners ,_support)
          `(Done
            ,(owners-view/generated/s 'q-rebuild/generated/s owners))]
         [`(q-last ,owners (q-answer ,answer-owners ,q-state))
          `(Last
            ,(owners-view/generated/s 'q-rebuild/generated/s owners)
            (Answer
             ,(owners-view/generated/s
               'q-rebuild/generated/s
               answer-owners)
             ,(q-state->s/generated/s q-state)))]
         [_
          (error 'q-rebuild/generated/s
                 "expected neutral core frontier, received ~e"
                 neutral)]))
     (define (focus-path->q/generated/s path [support '()])
       (match path
         [(? (lambda (datum) (equal? datum (term hole))))
          (values 'q-focus-hole support)]
         [`(Conj ,owners ,inner ,goal)
          (define support-here
            (owners->support/generated/s owners support))
          (define-values (q-inner support-at-hole)
            (focus-path->q/generated/s inner support-here))
          (values
           `(q-focus-conj ,owners ,q-inner ,goal)
           support-at-hole)]
         [_
          (error 'q-focus-export/generated/s
                 "expected an S WorkPath, received ~e"
                 path)]))
     (define (q-focus-export/generated/s focused focus)
       (match focus
         [`(More ,path)
          (define-values (q-path support-at-hole)
            (focus-path->q/generated/s path))
          `(q-focused
            ,(work->q/generated/s focused support-at-hole)
            (q-work-focus ,q-path))]
         [_
          (error 'q-focus-export/generated/s
                 "expected an S WorkFocus, received ~e"
                 focus)]))
     (define (q-focus-path->s/generated/s q-path)
       (match q-path
         ['q-focus-hole (term hole)]
         [`(q-focus-conj ,owners ,q-inner ,goal)
          `(Conj
            ,(owners-view/generated/s
              'q-focus-rebuild/generated/s
              owners)
            ,(q-focus-path->s/generated/s q-inner)
            ,goal)]
         [_
          (error 'q-focus-rebuild/generated/s
                 "expected a neutral WorkPath, received ~e"
                 q-path)]))
     (define (q-focus-rebuild/generated/s neutral)
       (match neutral
         [`(q-focused ,q-work (q-work-focus ,q-path))
          (list
           (q-work->s/generated/s q-work)
           `(More ,(q-focus-path->s/generated/s q-path)))]
         [_
          (error 'q-focus-rebuild/generated/s
                 "expected a neutral focused pair, received ~e"
                 neutral)])))
    #:export q-export/generated/s
    #:rebuild q-rebuild/generated/s
    #:focus-export q-focus-export/generated/s
    #:focus-rebuild q-focus-rebuild/generated/s]])

(define-generated-core-source
  #:strategy core-s-representation-strategy
  #:language generated-core-s-lang
  #:relation generated-core-s-red
  #:raw-successors raw-successors/generated/s
  #:branch-copy branch-copy/generated/s
  #:source-interface generated-core-s-source)
