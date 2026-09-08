#lang racket

(require redex/reduction-semantics
         (only-in "../../../shared/grammar-s.rkt" StrictS)
         (only-in "../../../shared/kernel.rkt"
                  owners-support owners-append fresh-names substitute-goal)
         "../../../retained-scope/relations.rkt"
         (only-in "data.rkt" atomic/data Failure Success))
(provide (all-defined-out))

;; A small-step presentation of interpreter.rkt's demand equations. In the
;; base, mplus demands ONLY its left computation; Yield's tail is a computation
;; but is NOT an evaluation context. There is no context below Delay or More.
;; Right-active mplus and YieldR are genuine grammar extensions, not a flag
;; allowing hidden DisjR values into the two base policies.
(define-extended-language OnlineBase StrictS
  [r ::= (variable-prefix r:)]
  [g ::= .... (r t ... tag)]
  [Γ ::= ((r (x ...) g) ...)]
  [S ::= (Empty owners) (One owners σ)
         (Yield owners A c) (Delay owners c)]
  [c ::= S (eval owners g σ) (mplus owners c c) (bind owners c g)]
  [F ::= (Done owners) (Last owners A) (Emit owners A F)
         (Forced owners F) (More (Delay owners c))]
  [o ::= F (commit c) (advance F) (Emit owners A o) (Forced owners o)]
  [E ::= hole (mplus owners E c) (bind owners E g)]
  [H ::= hole (commit E) (Emit owners A H) (Forced owners H)]
  [policy ::= dfs flip]
  [p ::= (program policy Γ o)])
(define-extended-language OnlineRail OnlineBase
  [S ::= .... (YieldR owners c A)]
  [c ::= .... (mplusR owners c c)]
  [E ::= .... (mplusR owners c E)]
  [policy ::= rail])

(define (source-in-domain? program)
  (or (redex-match? OnlineBase p program) (redex-match? OnlineRail p program)))
(define (search-value? term)
  (match term
    [(or `(Empty ,_) `(One ,_ ,_) `(Yield ,_ ,_ ,_)
         `(YieldR ,_ ,_ ,_) `(Delay ,_ ,_)) #t]
    [_ #f]))
(define (frontier? term)
  (match term
    [(or `(Done ,_) `(Last ,_ ,_) `(More (Delay ,_ ,_))) #t]
    [(or `(Emit ,_ ,_ ,tail) `(Forced ,_ ,tail)) (frontier? tail)]
    [_ #f]))
(define (complete? term)
  (match term
    [(or `(Done ,_) `(Last ,_ ,_)) #t]
    [(or `(Emit ,_ ,_ ,tail) `(Forced ,_ ,tail)) (complete? tail)]
    [_ #f]))

;; These frames are the data form of the displayed contexts. A focus always
;; records nearest frame first. No observer, procedure or closure table enters
;; either the source state or its decomposition.
(struct focus (term frames) #:transparent)
(define (plug-frame frame term)
  (match frame
    [`(left ,owners ,right) `(mplus ,owners ,term ,right)]
    [`(right ,owners ,left) `(mplusR ,owners ,left ,term)]
    [`(bind ,owners ,goal) `(bind ,owners ,term ,goal)]
    ['commit `(commit ,term)]
    [`(emit ,owners ,answer) `(Emit ,owners ,answer ,term)]
    [`(forced ,owners) `(Forced ,owners ,term)]))
(define (plug term frames)
  (match frames
    ['() term]
    [(cons frame rest) (plug (plug-frame frame term) rest)]))
(define (decompose term [frames '()])
  (match term
    [`(mplus ,owners ,left ,right) #:when (not (search-value? left))
     (decompose left (cons `(left ,owners ,right) frames))]
    [`(mplusR ,owners ,left ,right) #:when (not (search-value? right))
     (decompose right (cons `(right ,owners ,left) frames))]
    [`(bind ,owners ,left ,goal) #:when (not (search-value? left))
     (decompose left (cons `(bind ,owners ,goal) frames))]
    [`(commit ,body) #:when (not (search-value? body))
     (decompose body (cons 'commit frames))]
    [`(Emit ,owners ,answer ,tail) #:when (not (frontier? tail))
     (decompose tail (cons `(emit ,owners ,answer) frames))]
    [`(Forced ,owners ,tail) #:when (not (frontier? tail))
     (decompose tail (cons `(forced ,owners) frames))]
    [_ (focus term frames)]))
(define (frame-support frames)
  (match frames
    ['() '()]
    [(cons frame rest)
     (define inherited (frame-support rest))
     (match frame
       ['commit inherited]
       [`(,_ ,owners ,_ ...) (owners-support owners inherited)])]))

;; The direct scope-computation attaches before running, including an unused
;; introduction. It is not a post-return conversion or extra reduction phase.
(define (lift owners computation)
  (match computation
    [`(,constructor ,local ,fields ...)
     #:when (member constructor '(eval mplus mplusR bind Empty One Yield YieldR Delay))
     `(,constructor ,(owners-append owners local) ,@fields)]))

(define (contract policy definitions term inherited)
  (match term
    [`(eval ,owners (,left ∨ ,right ,_) ,state)
     (list "eval-disj" `(mplus ,owners (eval (Owners) ,left ,state)
                              (eval (Owners) ,right ,state)))]
    [`(eval ,owners (,left ∧ ,right ,_) ,state)
     (list "eval-conj" `(bind ,owners (eval (Owners) ,left ,state) ,right))]
    [`(eval ,owners (∃ ,binders ,body ,tag) ,state)
     (define intro (fresh-names (owners-support owners inherited) (length binders)))
     (list "eval-fresh"
           `(eval ,(owners-append owners `(Owners (Owner ,intro ,tag)))
                  ,(substitute-goal body (map list binders intro)) ,state))]
    [`(eval ,owners (suspend ,body ,_) ,state)
     (list "eval-suspend" `(Delay ,owners (eval (Owners) ,body ,state)))]
    [`(eval ,owners ,(? relation-call? call) ,state)
     (list "eval-call" `(eval ,owners ,(expand-call definitions call) ,state))]
    [`(eval ,owners ,atom ,state)
     (list "eval-atom" (match (atomic/data atom state)
                         [(Failure) `(Empty ,owners)]
                         [(Success next) `(One ,owners ,next)]))]
    [`(mplus ,owners ,active ,passive) #:when (search-value? active)
     (contract-merge policy 'left owners active passive)]
    [`(mplusR ,owners ,passive ,active) #:when (search-value? active)
     (contract-merge policy 'right owners active passive)]
    [`(bind ,owners (Empty ,local) ,_)
     (list "bind-empty" `(Empty ,(owners-append owners local)))]
    [`(bind ,owners (One ,local ,state) ,goal)
     (list "bind-one" `(eval ,(owners-append owners local) ,goal ,state))]
    [`(bind ,owners (Yield ,local (Answer ,private ,state) ,tail) ,goal)
     (list "bind-yield"
           `(mplus ,(owners-append owners local) (eval ,private ,goal ,state)
                   (bind (Owners) ,tail ,goal)))]
    [`(bind ,owners (YieldR ,local ,tail (Answer ,private ,state)) ,goal)
     (list "bind-yield-right"
           `(mplusR ,(owners-append owners local) (bind (Owners) ,tail ,goal)
                    (eval ,private ,goal ,state)))]
    [`(bind ,owners (Delay ,local ,body) ,goal)
     (list "bind-delay"
           `(Delay ,(owners-append owners local) (bind (Owners) ,body ,goal)))]
    [`(commit (Empty ,owners)) (list "commit-empty" `(Done ,owners))]
    [`(commit (One ,owners ,state))
     (list "commit-one" `(Last (Owners) (Answer ,owners ,state)))]
    [`(commit (Yield ,owners ,answer ,tail))
     (list "commit-yield" `(Emit ,owners ,answer (commit ,tail)))]
    [`(commit (YieldR ,owners ,tail ,answer))
     (list "commit-yield-right" `(Emit ,owners ,answer (commit ,tail)))]
    [`(commit ,(and delay `(Delay ,_ ,_))) (list "commit-delay" `(More ,delay))]
    [`(advance ,(and final (or `(Done ,_) `(Last ,_ ,_))))
     (list "advance-terminal" final)]
    [`(advance (Emit ,owners ,answer ,tail))
     (list "advance-emit" `(Emit ,owners ,answer (advance ,tail)))]
    [`(advance (Forced ,owners ,tail))
     (list "advance-forced" `(Forced ,owners (advance ,tail)))]
    [`(advance (More (Delay ,owners ,body)))
     (list "advance-delay" `(Forced ,owners (commit ,body)))]
    [_ #f]))

(define (contract-merge policy side owners active passive)
  (define constructor (if (eq? side 'left) 'mplus 'mplusR))
  (define (yield answer rest)
    (if (eq? side 'left) `(Yield ,owners ,answer ,rest)
        `(YieldR ,owners ,rest ,answer)))
  (define (merge residual)
    (if (eq? side 'left) `(,constructor (Owners) ,residual ,passive)
        `(,constructor (Owners) ,passive ,residual)))
  (match active
    [`(Empty ,_) (list "mplus-empty" (lift owners passive))]
    [`(One ,local ,state)
     (list "mplus-one" (yield `(Answer ,local ,state) passive))]
    [(or `(Yield ,local (Answer ,private ,state) ,rest)
         `(YieldR ,local ,rest (Answer ,private ,state)))
     (list "mplus-yield"
           (yield `(Answer ,(owners-append local private) ,state)
                  (merge (lift local rest))))]
    [`(Delay ,local ,body)
     (define residual (lift local body))
     (list "mplus-delay"
           `(Delay ,owners
                   ,(match policy
                      ['dfs `(mplus (Owners) ,residual ,passive)]
                      ['flip `(mplus (Owners) ,passive ,residual)]
                      ['rail
                       (match side
                         ['left `(mplusR (Owners) ,residual ,passive)]
                         ['right `(mplus (Owners) ,passive ,residual)])])))]))

(define (step program)
  (match-define `(program ,policy ,definitions ,body) program)
  (match-define (focus redex frames) (decompose body))
  (match (contract policy definitions redex (frame-support frames))
    [#f #f]
    [(list label next) (list label `(program ,policy ,definitions ,(plug next frames)))]))
(define (initial goal #:policy [policy 'flip] #:relations [definitions '()]
                 #:owners [owners '(Owners)] #:state [state '(state () () () (label "initial"))])
  `(program ,policy ,definitions (commit (eval ,owners ,goal ,state))))
(define (advance program)
  (match-define `(program ,policy ,definitions ,body) program)
  (unless (and (frontier? body) (not (complete? body)))
    (raise-argument-error 'advance "paused source program" program))
  `(program ,policy ,definitions (advance ,body)))

;; Forget stable slot positions in the extended interpreter's own Search and
;; resumption language. This is separate from the native lattice erasure.
;; Allocation scopes, grouping, tags, definitions and stores remain literal.
(define (erase-orientation term)
  (match term
    [`(program rail ,definitions ,body) `(program flip ,definitions ,(erase-orientation body))]
    [`(mplusR ,owners ,left ,right)
     `(mplus ,owners ,(erase-orientation right) ,(erase-orientation left))]
    [`(YieldR ,owners ,tail ,answer) `(Yield ,owners ,answer ,(erase-orientation tail))]
    [`(mplus ,owners ,left ,right)
     `(mplus ,owners ,(erase-orientation left) ,(erase-orientation right))]
    [`(bind ,owners ,body ,goal) `(bind ,owners ,(erase-orientation body) ,goal)]
    [`(,(and constructor (or 'Yield 'Emit)) ,owners ,answer ,tail)
     `(,constructor ,owners ,answer ,(erase-orientation tail))]
    [`(,(and constructor (or 'Delay 'Forced)) ,owners ,body)
     `(,constructor ,owners ,(erase-orientation body))]
    [`(,(and constructor (or 'commit 'advance 'More)) ,body)
     `(,constructor ,(erase-orientation body))]
    [(or `(eval ,_ ,_ ,_) `(One ,_ ,_) `(Empty ,_) `(Last ,_ ,_) `(Done ,_)) term]))
(define (erase-orientation-label label)
  (match label
    ["bind-yield-right" "bind-yield"]
    ["commit-yield-right" "commit-yield"]
    [_ label]))

(define (drive program [fuel 10000])
  (match (step program)
    [#f program]
    [(list _ next)
     (when (zero? fuel) (error 'drive "source step budget exhausted"))
     (drive next (sub1 fuel))]))
