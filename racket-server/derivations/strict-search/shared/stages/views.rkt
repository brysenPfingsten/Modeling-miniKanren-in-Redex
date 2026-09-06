#lang racket

(require redex/reduction-semantics "schema.rkt")
(provide define-S-view define-ownerless-view)

;; These macros depend only on supplied grammar/value predicates and structural
;; frame records. Each semantic presentation instantiates its own view.
;; These are native constructor views. S retains every grouped Owner field;
;; E and N retain their own support/counter states and failure summaries.
;; No branch here invokes a contraction or performs row addressing/erasure.
(define-syntax-rule (define-S-view name language value? frontier?)
 (define (name computation)
  (unless (redex-match? language q computation)
    (raise-argument-error 'name "computation admitted by this feature language" computation))
  (cond
    [(or (value? computation) (frontier? computation)) (Value)]
    [else
     (match computation
       [`(eval ,_ ,_ ,_) (Local)]
       [`(mplus ,owners ,left ,right)
        (if (and (value? left) (value? right))
            (Local)
            (Descend left (Frame 'merge-left `(mplus ,owners) (list right) owners)))]
       [`(bind ,owners ,search ,goal)
        (if (value? search)
            (Local)
            (Descend search (Frame 'bind `(bind ,owners) (list goal) owners)))]
       [`(Yield ,owners ,answer ,tail)
        (Descend tail (Frame 'yield `(Yield ,owners ,answer) '() owners))]
       [`(force ,search)
        (if (value? search) (Local) (Descend search (Frame 'force '(force) '() #f)))]
       [`(render ,search)
        (if (value? search) (Local) (Descend search (Frame 'render '(render) '() #f)))]
       [`(commit ,search)
        (if (value? search) (Local) (Descend search (Frame 'commit '(commit) '() #f)))]
       [`(,(and constructor (or 'advance 'collect)) ,frontier)
        (if (frontier? frontier)
            (Local)
            (Descend frontier (Frame constructor (list constructor) '() #f)))]
       [`(Emit ,owners ,answer ,tail)
        (Descend tail (Frame 'emit `(Emit ,owners ,answer) '() owners))]
       [`(Forced ,owners ,tail)
        (Descend tail (Frame 'forced `(Forced ,owners) '() owners))]
       [_ (raise-argument-error 'name "strict S computation" computation)])])))

(define-syntax-rule (define-ownerless-view name language value? frontier?)
  (define (name computation)
    (unless (redex-match? language q computation)
      (raise-argument-error 'name "computation admitted by this feature language" computation))
    (cond
      [(or (value? computation) (frontier? computation)) (Value)]
      [else
       (match computation
         [`(eval ,_ ,_) (Local)]
         [`(mplus ,left ,right)
          (if (and (value? left) (value? right))
              (Local)
              (Descend left (Frame 'merge-left '(mplus) (list right) #f)))]
         [`(bind ,search ,goal)
          (if (value? search) (Local) (Descend search (Frame 'bind '(bind) (list goal) #f)))]
         [`(Yield ,state ,tail) (Descend tail (Frame 'yield `(Yield ,state) '() #f))]
         [`(force ,search)
          (if (value? search) (Local) (Descend search (Frame 'force '(force) '() #f)))]
         [`(render ,search)
          (if (value? search) (Local) (Descend search (Frame 'render '(render) '() #f)))]
         [`(commit ,search)
          (if (value? search) (Local) (Descend search (Frame 'commit '(commit) '() #f)))]
         [`(,(and constructor (or 'advance 'collect)) ,frontier)
          (if (frontier? frontier)
              (Local)
              (Descend frontier (Frame constructor (list constructor) '() #f)))]
         [`(Emit ,state ,tail) (Descend tail (Frame 'emit `(Emit ,state) '() #f))]
         [`(Forced ,tail) (Descend tail (Frame 'forced '(Forced) '() #f))]
         [_ (raise-argument-error 'name "native strict computation" computation)])])))
