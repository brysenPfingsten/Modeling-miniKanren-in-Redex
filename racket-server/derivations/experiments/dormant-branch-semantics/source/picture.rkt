#lang racket

(require racket/hash
         "./answer-node.rkt")

(provide cfg->operational-picture
         cfg->extensional-picture
         program-query-var-count)

(define (project-config-frontier cfg)
  (match cfg
    [`(,(? list?) ,F) F]
    [F F]))

(define (empty-node)
  (hasheq 'name "Empty"
          'renderRole "terminal"))

(define (freshened-node intro child tag)
  (hasheq 'name "Freshened"
          'renderRole "freshened"
          'id (label->visible-id tag)
          'vars (map term->visible-json intro)
          'activeChildIndex 0
          'children (list child)))

(define (forced-node child)
  ;; "Deferred" is the friendly UI label; the renderer contract uses the
  ;; semantic role "forced" for this persistent frontier frame.
  (hasheq 'name "Deferred"
          'renderRole "forced"
          'activeChildIndex 0
          'children (list child)))

(define (emit-node left right)
  (hasheq 'name "Emit"
          'renderRole "stream-emit"
          'resolvedChildIndices '(0)
          'resolvedColor "green"
          'activeChildIndex 1
          'children (list left right)))

(define (answer-state-fields σ introductions num-query-variables)
  (for/hasheq ([(k v) (in-hash (state->answer-node σ
                                                    introductions
                                                    num-query-variables))]
               #:when (member k '(stateId sub disequalities trail reified)))
    (values k v)))

(define (owner-records->picture owners introductions render-body)
  (match owners
    ['()
     (render-body introductions)]
    [(cons `(Owner ,intro ,tag) owners-rest)
     (freshened-node
      intro
      (owner-records->picture owners-rest
                              (append introductions intro)
                              render-body)
      tag)]))

(define (owners->picture owners introductions render-body)
  (match owners
    [(list 'Owners owner ...)
     (owner-records->picture owner introductions render-body)]))

(define (goal-query-vars g)
  (match g
    [`(∃ ,d ,_ ,_) (length d)]
    [`(suspend ,g_1 ,_) (goal-query-vars g_1)]
    [`(,g_1 ∧ ,g_2 ,_) (max (goal-query-vars g_1)
                            (goal-query-vars g_2))]
    [`(,g_1 ∨ ,g_2 ,_) (max (goal-query-vars g_1)
                            (goal-query-vars g_2))]
    [_ 0]))

(define (num-query-vars/tree tree)
  (match tree
    [`(More ,inner)
     (num-query-vars/tree inner)]
    [(or `(Last (Owners ,_ ...) ,inner)
         `(PendingDelay (Owners ,_ ...) ,inner)
         `(Forced (Owners ,_ ...) ,inner))
     (num-query-vars/tree inner)]
    [`(Emit (Owners ,_ ...) ,answer ,frontier)
     (max (num-query-vars/tree answer)
          (num-query-vars/tree frontier))]
    [`(Work (Owners ,_ ...) ,g ,_σ)
     (goal-query-vars g)]
    [`(Conj (Owners ,_ ...) ,work ,g)
     (max (num-query-vars/tree work)
          (goal-query-vars g))]
    [(or `(DisjL (Owners ,_ ...) ,left ,right)
         `(DisjR (Owners ,_ ...) ,left ,right))
     (max (num-query-vars/tree left)
          (num-query-vars/tree right))]
    [_ 0]))

(define (num-query-vars cfg)
  (match cfg
    [`(,(? list?) ,frontier)
     (num-query-vars/tree frontier)]
    [frontier
     (num-query-vars/tree frontier)]))

(define (program-query-var-count cfg)
  (num-query-vars cfg))

(define (tree->picture tree
                       introductions
                       num-query-variables
                       #:extensional? [extensional? #f])
  (match tree
    [`(Done ,owners)
     (owners->picture owners introductions
                      (lambda (_introductions)
                        (empty-node)))]
    [`(Dead ,owners)
     (owners->picture owners introductions
                      (lambda (_introductions)
                        (empty-node)))]
    [`(More ,work)
     (tree->picture work introductions num-query-variables
                    #:extensional? extensional?)]
    [`(Last ,owners ,answer)
     (owners->picture
      owners introductions
      (lambda (introductions^)
        (tree->picture answer introductions^ num-query-variables
                       #:extensional? extensional?)))]
    [`(Forced ,owners ,frontier)
     (owners->picture
      owners introductions
      (lambda (introductions^)
        (if extensional?
            (tree->picture frontier introductions^ num-query-variables
                           #:extensional? #t)
            (forced-node
             (tree->picture frontier introductions^ num-query-variables
                            #:extensional? #f)))))]
    [`(Emit ,owners ,answer ,frontier)
     (owners->picture
      owners introductions
      (lambda (introductions^)
        (emit-node
         (tree->picture answer introductions^ num-query-variables
                        #:extensional? extensional?)
         (tree->picture frontier introductions^ num-query-variables
                        #:extensional? extensional?))))]
    [`(Work ,owners ,g (state ,sub ,dis ,trail ,tag))
     (owners->picture
      owners introductions
      (lambda (introductions^)
        (hash-union (goal->visible-node g)
                    (answer-state-fields
                     `(state ,sub ,dis ,trail ,tag)
                     introductions^
                     num-query-variables))))]
    [`(DisjL ,owners ,left ,right)
     (owners->picture
      owners introductions
      (lambda (introductions^)
        (hasheq 'name "<-+"
                'renderRole "search-branch"
                'focusColor "#ff8000"
                'activeChildIndex 0
                'children
                (list (tree->picture left introductions^ num-query-variables
                                     #:extensional? extensional?)
                      (tree->picture right introductions^ num-query-variables
                                     #:extensional? extensional?)))))]
    [`(DisjR ,owners ,left ,right)
     (owners->picture
      owners introductions
      (lambda (introductions^)
        (hasheq 'name "+->"
                'renderRole "search-branch"
                'focusColor "#ff8000"
                'activeChildIndex 1
                'children
                (list (tree->picture left introductions^ num-query-variables
                                     #:extensional? extensional?)
                      (tree->picture right introductions^ num-query-variables
                                     #:extensional? extensional?)))))]
    [`(Conj ,owners ,work ,g)
     (owners->picture
      owners introductions
      (lambda (introductions^)
        (hasheq 'name "Conjunction"
                'renderRole "search-conjunction"
                'focusColor "blue"
                'activeChildIndex 0
                'children
                (list (tree->picture work introductions^ num-query-variables
                                     #:extensional? extensional?)
                      (goal->visible-node g)))))]
    [`(PendingDelay ,owners ,work)
     (owners->picture
      owners introductions
      (lambda (introductions^)
        (hasheq 'name "Delay"
                'renderRole "delay"
                'activeChildIndex 0
                'children
                (list (tree->picture work introductions^ num-query-variables
                                     #:extensional? extensional?)))))]
    [`(state ,sub ,dis ,trail ,tag)
     (state->answer-node `(state ,sub ,dis ,trail ,tag)
                         introductions
                         num-query-variables)]
    [`(Returned ,owners ,σ)
     (owners->picture owners introductions
                      (lambda (introductions^)
                        (state->answer-node σ
                                            introductions^
                                            num-query-variables)))]
    [`(Answer ,owners ,σ)
     (owners->picture owners introductions
                      (lambda (introductions^)
                        (state->answer-node σ
                                            introductions^
                                            num-query-variables)))]
    [_ (error 'tree->picture
              "unknown tree/frontier shape: ~e"
              tree)]))

(define (cfg->operational-picture cfg [num-query-variables (num-query-vars cfg)])
  (tree->picture (project-config-frontier cfg)
                 '()
                 num-query-variables
                 #:extensional? #f))

(define (cfg->extensional-picture cfg [num-query-variables (num-query-vars cfg)])
  (tree->picture (project-config-frontier cfg)
                 '()
                 num-query-variables
                 #:extensional? #t))
