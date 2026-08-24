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
         work-focus-prefix-support/open/generated/s
         transfer-work-prefix/open/generated/s
         transfer-work-prefix/generated/s
         q-export-local-prefix/generated/s
         q-rebuild-local-prefix/generated/s
         q-work-export/open/generated/s
         q-work-support/open/generated/s
         q-work-rebuild/open/generated/s
         q-frontier-export/open/generated/s
         q-frontier-support/open/generated/s
         q-frontier-rebuild/open/generated/s
         q-path-export/open/generated/s
         q-path-rebuild/open/generated/s
         q-failure-export/generated/s
         q-failure-rebuild/generated/s
         q-address-goal/open/generated/s
         q-export/generated/s
         q-rebuild/generated/s
         q-focus-export/generated/s
         q-focus-rebuild/generated/s
         q-root-focus-export/generated/s
         q-root-focus-rebuild/generated/s
         q-failure-focus-export/generated/s
         q-failure-focus-rebuild/generated/s
         q-terminal-export/generated/s
         q-terminal-rebuild/generated/s
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
    (define (work-focus-prefix-support/open/generated/s work-focus
                                                        support
                                                        recur)
      (match work-focus
        [(? (lambda (datum) (equal? datum (term hole)))) support]
        [`(More ,work-path)
         (recur work-path support)]
        [`(Conj ,owners ,work-path ,_goal)
         (recur work-path
                (owners->support/generated/s owners support))]
        [_
         (error 'work-focus-prefix-support/open/generated/s
                "expected an S WorkFocus, received ~e"
                work-focus)]))
    (define (work-focus-prefix-support/generated/s work-focus
                                                   [support '()])
      (work-focus-prefix-support/open/generated/s
       work-focus
       support
       work-focus-prefix-support/generated/s))
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
               (term (WORK-FOCUS-PREFIX-HOOK WorkFocus ())))
              (length (term (x_bound ...)))))
     (where g_new
            (SUBST-GOAL-HOOK g ((x_bound rv_new) ...))))]
   #:work-focus-prefix-open work-focus-prefix-support/open/generated/s
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
   #:extension-prefix
   [#:transfer-work-open transfer-work-prefix/open/generated/s
    #:transfer-work transfer-work-prefix/generated/s
    #:Q-export-local q-export-local-prefix/generated/s
    #:Q-rebuild-local q-rebuild-local-prefix/generated/s]
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
    ((EXTEND-SUPPLY-HOOK supply_in supply_local supply_prefix))
    #:root wf-core/generated/s?]
   #:q-map
   [#:definitions
    ((define (address/generated/s value _support) value)
     (define (q-address-goal/open/generated/s _recur goal _support)
       goal)
     (define (owners-view/generated/s who value)
       (match value
         [`(Owners . ,_) value]
         [_
          (error who
                 "neutral view has no S Owner provenance: ~e"
                 value)]))
     (define (owners-append/host/generated/s outer inner)
       (match* (outer inner)
         [(`(Owners ,outer-owners ...)
           `(Owners ,inner-owners ...))
          `(Owners ,@outer-owners ,@inner-owners)]
         [(_ _)
          (error 'transfer-work-prefix/open/generated/s
                 "expected two Owner sequences, received ~e and ~e"
                 outer
                 inner)]))
     (define (transfer-work-prefix/open/generated/s prefix work extension)
       (match work
         [`(Work ,local ,goal ,state)
          `(Work
            ,(owners-append/host/generated/s prefix local)
            ,goal
            ,state)]
         [`(Returned ,local ,state)
          `(Returned
            ,(owners-append/host/generated/s prefix local)
            ,state)]
         [`(Dead ,local)
          `(Dead ,(owners-append/host/generated/s prefix local))]
         [`(Conj ,local ,inner ,goal)
          `(Conj
            ,(owners-append/host/generated/s prefix local)
            ,inner
            ,goal)]
         [_ (extension prefix work)]))
     (define (transfer-work-prefix/generated/s prefix work)
       (transfer-work-prefix/open/generated/s
        prefix
        work
        (lambda (_prefix unsupported)
          (error 'transfer-work-prefix/generated/s
                 "expected S work, received ~e"
                 unsupported))))
     (define (q-export-local-prefix/generated/s local accumulated)
       (list
        (owners-view/generated/s
         'q-export-local-prefix/generated/s
         local)
        (owners->support/generated/s local accumulated)))
     (define (q-rebuild-local-prefix/generated/s provenance)
       (owners-view/generated/s
        'q-rebuild-local-prefix/generated/s
        provenance))
     (define (state->q/generated/s state support)
       (match state
         [`(state ,sub ,dis ,trail ,state-tag)
          `(q-state ,support ,sub ,dis ,trail ,state-tag)]
         [_
          (error 'q-export/generated/s
                 "expected S state, received ~e"
                 state)]))
     (define (q-work-export/open/generated/s work support recur)
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
            ,(recur inner support-here)
            ,goal)]
         [_
          (error 'q-export/generated/s
                 "expected S work, received ~e"
                 work)]))
     (define (work->q/generated/s work [support '()])
       (q-work-export/open/generated/s
        work
        support
        work->q/generated/s))
     (define (q-work-support/open/generated/s q-work recur)
       (match q-work
         [`(q-work ,_ ,_ (q-state ,support ,_ ,_ ,_ ,_)) support]
         [`(q-returned ,_ (q-state ,support ,_ ,_ ,_ ,_)) support]
         [`(q-dead ,_ ,support) support]
         [`(q-conj ,_ ,inner ,_) (recur inner)]
         [_
          (error 'q-work-support/open/generated/s
                 "expected neutral work, received ~e"
                 q-work)]))
     (define (q-work-support/generated/s q-work)
       (q-work-support/open/generated/s
        q-work
        q-work-support/generated/s))
     (define (q-frontier-export/open/generated/s frontier support recur-work)
       (match frontier
         [`(More ,work)
          `(q-more ,(recur-work work support))]
         [`(Done ,owners)
          `(q-done
            ,owners
            ,(owners->support/generated/s owners support))]
         [`(Last ,owners (Answer ,answer-owners ,state))
          (define prefix
            (owners->support/generated/s owners support))
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
     (define (q-export/generated/s frontier)
       (q-frontier-export/open/generated/s
        frontier
        '()
        work->q/generated/s))
     (define (q-frontier-support/open/generated/s neutral recur-work)
       (match neutral
         [`(q-more ,q-work) (recur-work q-work)]
         [`(q-done ,_ ,support) support]
         [`(q-last ,_ (q-answer ,_ (q-state ,support ,_ ,_ ,_ ,_)))
          support]
         [_
          (error 'q-frontier-support/open/generated/s
                 "expected neutral frontier, received ~e"
                 neutral)]))
     (define (q-frontier-support/generated/s neutral)
       (q-frontier-support/open/generated/s
        neutral
        q-work-support/generated/s))
     (define (q-state->s/generated/s q-state)
       (match q-state
         [`(q-state ,_support ,sub ,dis ,trail ,state-tag)
          `(state ,sub ,dis ,trail ,state-tag)]
         [_
          (error 'q-rebuild/generated/s
                 "expected neutral state, received ~e"
                 q-state)]))
     (define (q-work-rebuild/open/generated/s
              q-work support recur map-goal)
       (match q-work
         [`(q-work ,owners ,goal ,q-state)
          `(Work
            ,(owners-view/generated/s 'q-rebuild/generated/s owners)
            ,(map-goal goal support)
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
            ,(recur inner support)
            ,(map-goal goal support))]
         [_
          (error 'q-rebuild/generated/s
                 "expected neutral work, received ~e"
                 q-work)]))
     (define (q-work->s/generated/s
              q-work
              [support (q-work-support/generated/s q-work)])
       (q-work-rebuild/open/generated/s
        q-work
        support
        q-work->s/generated/s
        (lambda (goal _support) goal)))
     (define (q-frontier-rebuild/open/generated/s
              neutral support recur-work)
       (match neutral
         [`(q-more ,q-work)
          `(More ,(recur-work q-work support))]
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
     (define (q-rebuild/generated/s neutral)
       (q-frontier-rebuild/open/generated/s
        neutral
        (q-frontier-support/generated/s neutral)
        q-work->s/generated/s))
     (define (q-path-export/open/generated/s path support recur)
       (match path
         [(? (lambda (datum) (equal? datum (term hole))))
          (values 'q-focus-hole support)]
         [`(Conj ,owners ,inner ,goal)
          (define support-here
            (owners->support/generated/s owners support))
          (define-values (q-inner support-at-hole)
            (recur inner support-here))
          (values
           `(q-focus-conj ,owners ,q-inner ,goal)
           support-at-hole)]
         [_
          (error 'q-focus-export/generated/s
                 "expected an S WorkPath, received ~e"
                 path)]))
     (define (focus-path->q/generated/s path [support '()])
       (q-path-export/open/generated/s
        path
        support
        focus-path->q/generated/s))
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
     (define (q-path-rebuild/open/generated/s
              q-path support recur map-goal)
       (match q-path
         ['q-focus-hole (term hole)]
         [`(q-focus-conj ,owners ,q-inner ,goal)
          `(Conj
            ,(owners-view/generated/s
              'q-focus-rebuild/generated/s
              owners)
            ,(recur q-inner support)
            ,(map-goal goal support))]
         [_
          (error 'q-focus-rebuild/generated/s
                 "expected a neutral WorkPath, received ~e"
                 q-path)]))
     (define (q-focus-path->s/generated/s q-path [support '()])
       (q-path-rebuild/open/generated/s
        q-path
        support
        q-focus-path->s/generated/s
        (lambda (goal _support) goal)))
     (define (q-focus-rebuild/generated/s neutral)
       (match neutral
         [`(q-focused ,q-work (q-work-focus ,q-path))
          (define support (q-work-support/generated/s q-work))
          (list
           (q-work->s/generated/s q-work support)
           `(More ,(q-focus-path->s/generated/s q-path support)))]
         [_
          (error 'q-focus-rebuild/generated/s
                 "expected a neutral focused pair, received ~e"
                 neutral)]))
     (define (q-root-focus-export/generated/s frontier spine)
       (unless (equal? spine (term hole))
         (error 'q-root-focus-export/generated/s
                "expected the S root spine, received ~e"
                spine))
       (match frontier
         [`(More ,work)
          `(q-root-focused ,(work->q/generated/s work))]
         [other
          (error 'q-root-focus-export/generated/s
                 "expected an S root frontier, received ~e"
                 other)]))
     (define (q-root-focus-rebuild/generated/s neutral)
       (match neutral
         [`(q-root-focused ,q-work)
          (define support (q-work-support/generated/s q-work))
          (list `(More ,(q-work->s/generated/s q-work support))
                (term hole))]
         [other
          (error 'q-root-focus-rebuild/generated/s
                 "expected a neutral root focus, received ~e"
                 other)]))
     (define (q-failure-export/generated/s summary prefix)
       (define owners
         (owners-view/generated/s 'q-failure-export/generated/s summary))
       (list owners
             (owners->support/generated/s owners prefix)))
     (define (q-failure-rebuild/generated/s provenance _support)
       (owners-view/generated/s
        'q-failure-rebuild/generated/s
        provenance))
     (define (q-failure-focus-export/generated/s summary focus)
       (match focus
         [`(More ,path)
          (define-values (q-path support-at-hole)
            (focus-path->q/generated/s path))
          (match-define (list owners support)
            (q-failure-export/generated/s summary support-at-hole))
          `(q-failure-focused
            ,owners
            ,support
            (q-work-focus ,q-path))]
         [other
          (error 'q-failure-focus-export/generated/s
                 "expected an S WorkFocus, received ~e"
                 other)]))
     (define (q-failure-focus-rebuild/generated/s neutral)
       (match neutral
         [`(q-failure-focused ,owners ,support (q-work-focus ,q-path))
          (list
           (q-failure-rebuild/generated/s owners support)
           `(More ,(q-focus-path->s/generated/s q-path support)))]
         [other
          (error 'q-failure-focus-rebuild/generated/s
                 "expected a neutral failure focus, received ~e"
                 other)]))
     (define (q-terminal-export/generated/s terminal)
       (q-frontier-export/open/generated/s
        terminal
        '()
        work->q/generated/s))
     (define (q-terminal-rebuild/generated/s neutral)
       (q-frontier-rebuild/open/generated/s
        neutral
        (q-frontier-support/generated/s neutral)
        q-work->s/generated/s)))
    #:open
    [#:work-export q-work-export/open/generated/s
     #:work-support q-work-support/open/generated/s
     #:work-rebuild q-work-rebuild/open/generated/s
     #:frontier-export q-frontier-export/open/generated/s
     #:frontier-support q-frontier-support/open/generated/s
     #:frontier-rebuild q-frontier-rebuild/open/generated/s
     #:path-export q-path-export/open/generated/s
     #:path-rebuild q-path-rebuild/open/generated/s
     #:failure-export q-failure-export/generated/s
     #:failure-rebuild q-failure-rebuild/generated/s
     #:address-goal q-address-goal/open/generated/s]
    #:export q-export/generated/s
    #:rebuild q-rebuild/generated/s
    #:focus-export q-focus-export/generated/s
    #:focus-rebuild q-focus-rebuild/generated/s
    #:root-focus-export q-root-focus-export/generated/s
    #:root-focus-rebuild q-root-focus-rebuild/generated/s
    #:failure-focus-export q-failure-focus-export/generated/s
    #:failure-focus-rebuild q-failure-focus-rebuild/generated/s
    #:terminal-export q-terminal-export/generated/s
    #:terminal-rebuild q-terminal-rebuild/generated/s]])

(define-generated-core-source
  #:strategy core-s-representation-strategy
  #:language generated-core-s-lang
  #:relation generated-core-s-red
  #:raw-successors raw-successors/generated/s
  #:branch-copy branch-copy/generated/s
  #:source-interface generated-core-s-source)
