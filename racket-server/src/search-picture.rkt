#lang racket

(require racket/hash
         (only-in "../derivations/strict-search/shared/kernel.rkt"
                  named-variable? owners-support)
         (only-in "../derivations/strict-search/matrix/full-source.rkt" s-rel-value?))

(provide cfg->operational-picture
         committed-answer-nodes
         label->visible-id
         term->visible-json)

;; Presentation reads each source's actual configuration. Shared logical
;; states and owner groups share a view; control constructors remain distinct.
;; No source is stepped or converted into another execution carrier here.
(define (configuration-body configuration)
  (match configuration
    [`(program ,_ ,body) body]
    [`(,(? list?) ,body) body]
    [body body]))

(define (label->visible-id tag)
  (match tag
    [`(label ,id) id]
    [_ (format "~a" tag)]))

(define (with-source-id picture tag)
  (define id (label->visible-id tag))
  (if (string-prefix? id "hidden:") picture (hash-set picture 'id id)))

(define (visible-name name)
  (regexp-replace #px"^[xr]:([^«]+).*" (symbol->string name) "\\1"))

(define (term->visible-json term)
  (match term
    ['empty '()]
    [(? named-variable? variable)
     (define suffix (substring (symbol->string variable) 2))
     (or (string->number suffix) (hasheq 'var (symbol->string variable)))]
    [(? symbol? variable) (hasheq 'var (visible-name variable))]
    [`(sym ,name) (hasheq 'sym name)]
    [`(nat ,number) (hasheq 'num number)]
    [`(str ,string) (hasheq 'str string)]
    [`(,left : ,right)
     (hasheq 'pair (list (term->visible-json left) (term->visible-json right)))]
    [(? boolean?) term]
    [_ (error 'term->visible-json "unknown source term: ~e" term)]))

;; Reification only walks the existing substitution. Sparse introductions
;; are names, not a numerical bound or a request to rerun a logic program.
(define (walk term substitution [seen '()])
  (match (and (named-variable? term) (assoc term substitution))
    [#f term]
    [(list variable value)
     (when (member variable seen)
       (error 'reify "cyclic substitution at ~e" variable))
     (walk value substitution (cons variable seen))]))

(define (reify-term term substitution names)
  (match (walk term substitution)
    [(? named-variable? variable)
     (match (assoc variable names)
       [(cons _ name) (values name names)]
       [#f
        (define name (format "_.~a" (length names)))
        (values name (append names (list (cons variable name))))])]
    [`(,left : ,right)
     (define-values (left* names*) (reify-term left substitution names))
     (define-values (right* names**) (reify-term right substitution names*))
     (values (hasheq 'pair (list left* right*)) names**)]
    [value (values (term->visible-json value) names)]))

(define (reify-query variables substitution)
  (define-values (reversed _names)
    (for/fold ([reversed '()] [names '()]) ([variable (in-list variables)])
      (define-values (value names*) (reify-term variable substitution names))
      (values (cons value reversed) names*)))
  (match (reverse reversed)
    [(list value) value]
    [values values]))

(define (state-fields state introductions query-variables)
  (match state
    [`(state ,substitution ,disequalities ,trail ,tag)
     (hasheq
      'stateId (label->visible-id tag)
      ;; State's semantic tag need not distinguish different substitutions.
      ;; This exact structural key is presentation identity only, not a new
      ;; field in the source state or an allocation/event observer.
      'stateKey (format "~s" (list introductions state))
      'scope (map term->visible-json introductions)
      'sub (for/list ([(variable values) (in-dict substitution)])
             (match-define (list value) values)
             (hasheq 'key (term->visible-json variable)
                     'value (term->visible-json value)))
      'disequalities
      (for/list ([constraint (in-list disequalities)])
        (match-define (list left right) constraint)
        (hasheq 'left (term->visible-json left) 'right (term->visible-json right)))
      'trail
      (for/list ([crumb (in-list trail)])
        (match-define `(,left =? ,right ,source) crumb)
        (hasheq 'left (term->visible-json left) 'right (term->visible-json right)
                'id (label->visible-id source)))
      'reified (if (andmap (lambda (variable) (member variable introductions))
                          query-variables)
                   (reify-query query-variables substitution)
                   '()))]
    [_ (error 'state-fields "expected an S logical state: ~e" state)]))

(define (state-node state introductions query-variables committed?)
  (hash-union
   (hasheq 'name (if committed? "Answer" "Candidate")
           'renderRole (if committed? "answer-node" "candidate")
           'nodeColor (if committed? "green" "#fff2cc"))
   (state-fields state introductions query-variables)))

(define (node name role children [active #f] [color #f])
  (define result (hasheq 'name name 'renderRole role 'children children))
  (define focused (if color (hash-set result 'focusColor color) result))
  (if active (hash-set focused 'activeChildIndex active) focused))

(define (goal->picture goal)
  (match goal
    [`(,(and name (or 'succeed 'fail)) ,tag)
     (with-source-id (hasheq 'name (if (eq? name 'succeed) "Succeed" "Fail")
                              'renderRole "goal-leaf") tag)]
    [`(,left ,(and operator (or '=? '!=)) ,right ,tag)
     (with-source-id
      (hasheq 'name (if (eq? operator '=?) "Unify" "Disequality")
              'renderRole "goal-leaf"
              'left (term->visible-json left) 'right (term->visible-json right)) tag)]
    [`(,left ,(and operator (or '∧ '∨)) ,right ,tag)
     (with-source-id (node (if (eq? operator '∧) "Goal-Conj" "Goal-Disj")
                           "goal-branch" (list (goal->picture left) (goal->picture right))) tag)]
    [`(suspend ,body ,tag)
     (with-source-id (node "Goal-Delay" "goal-delay" (list (goal->picture body))) tag)]
    [`(∃ ,variables ,body ,tag)
     (with-source-id (hash-set (node "Fresh" "goal-fresh" (list (goal->picture body)))
                               'vars (map term->visible-json variables)) tag)]
    [`(,(? symbol? relation) ,arguments ... ,tag)
     #:when (string-prefix? (symbol->string relation) "r:")
     (with-source-id (hasheq 'name "Rel-Call" 'renderRole "goal-leaf"
                             'rel (visible-name relation)
                             'args (map term->visible-json arguments)) tag)]
    [_ (error 'goal->picture "unknown source goal: ~e" goal)]))

(define (with-owners owners introductions render)
  (match owners
    ['(Owners) (render introductions)]
    [`(Owners (Owner ,introduced ,tag) ,rest ...)
     (with-source-id
      (hash-set
       (node "Freshened" "freshened"
             (list (with-owners `(Owners ,@rest) (append introductions introduced) render)) 0)
       'vars (map term->visible-json introduced)) tag)]))

(define (tree->picture term introductions query-variables [committed? #f])
  (define (render child [world introductions] [answer? #f])
    (tree->picture child world query-variables answer?))
  (match term
    [`(,constructor ,(and owners `(Owners ,_ ...)) ,parts ...)
     (with-owners
      owners introductions
      (lambda (here)
        (match (cons constructor parts)
          [(list (and terminal (or 'Empty 'Done 'Dead)))
           (node (symbol->string terminal) (if (eq? terminal 'Done) "completed" "search-empty") '())]
          [`(,(and operation (or 'eval 'Work)) ,goal ,state)
           (hash-union (with-source-id
                        (node (if (eq? operation 'eval) "Eval" "Work")
                              "evaluation" (list (goal->picture goal)) 0 "#666")
                        (last goal))
                       (state-fields state here query-variables))]
          [`(,(and value (or 'One 'Returned)) ,state)
           (node (symbol->string value) "search-value"
                 (list (state-node state here query-variables #f)))]
          [`(Answer ,state) (state-node state here query-variables committed?)]
          [`(Yield ,answer ,tail)
           (node "Yield" "search-yield" (list (render answer here) (render tail here))
                 (and (not (s-rel-value? tail)) 1) "#a66b00")]
          [`(,(or 'Delay 'PendingDelay) ,body)
           (hash-set (node "Delay" "delay" (list (render body here))) 'suspended #t)]
          [`(,(and orientation (or 'DisjL 'DisjR)) ,left ,right)
           (node (if (eq? orientation 'DisjL) "<-+" "+->") "search-branch"
                 (list (render left here) (render right here))
                 (if (eq? orientation 'DisjL) 0 1) "#ff8000")]
          [`(Conj ,work ,goal)
           (node "Conjunction" "search-conjunction"
                 (list (render work here) (goal->picture goal)) 0 "blue")]
          [`(mplus ,left ,right)
           (node "Mplus" "search-merge" (list (render left here) (render right here))
                 (cond [(not (s-rel-value? left)) 0] [(not (s-rel-value? right)) 1] [else #f])
                 "#ff8000")]
          [`(bind ,search ,goal)
           (node "Bind" "search-bind" (list (render search here) (goal->picture goal))
                 (and (not (s-rel-value? search)) 0) "blue")]
          [`(Last ,answer)
           (hash-set* (node "Last" "completed" (list (render answer here #t)))
                      'resolvedChildIndices '(0) 'resolvedColor "green")]
          [`(Emit ,answer ,tail)
           (hash-set* (node "Emit" "stream-emit"
                            (list (render answer here #t) (render tail here)) 1)
                      'resolvedChildIndices '(0) 'resolvedColor "green")]
          [`(Forced ,tail) (node "Forced" "forced" (list (render tail here)) 0)]
          [_ (error 'tree->picture "unknown owned source term: ~e" term)])))]
    [`(More ,(and delay `(,(or 'Delay 'PendingDelay) ,_ ,_)))
     (node "More" "paused-frontier" (list (render delay)))]
    [`(More ,work) (node "More" "unfinished-frontier" (list (render work)) 0)]
    [`(,(and operation (or 'force 'commit 'advance 'collect 'render)) ,body)
     (node (string-titlecase (symbol->string operation))
           (if (eq? operation 'force) "internal-force" "observation")
           (list (render body)) 0)]
    [_ (error 'tree->picture "unknown source computation: ~e" term)]))

(define (cfg->operational-picture configuration query-variables)
  (tree->picture (configuration-body configuration) '() query-variables))

;; Follow the committed outer Frontier only. In particular, commit's Search
;; operand and Yield's Answer payload are never traversed for answers.
(define (committed-answer-nodes configuration query-variables)
  (define (walk-frontier frontier introductions)
    (match frontier
      [`(Emit ,owners (Answer ,private ,state) ,tail)
       (define here (owners-support owners introductions))
       (cons (state-node state (owners-support private here) query-variables #t)
             (walk-frontier tail here))]
      [`(Last ,owners (Answer ,private ,state))
       (list (state-node state (owners-support private (owners-support owners introductions)) query-variables #t))]
      [`(Forced ,owners ,tail) (walk-frontier tail (owners-support owners introductions))]
      [`(,(or 'advance 'collect) ,frontier) (walk-frontier frontier introductions)]
      [_ '()]))
  (walk-frontier (configuration-body configuration) '()))
