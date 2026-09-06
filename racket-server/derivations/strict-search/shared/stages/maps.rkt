#lang racket

(require "schema.rkt" "../kernel.rkt" (prefix-in q: "../maps.rkt"))

(provide D-SE D-EN D-SN Z-SE Z-EN Z-SN M-SE M-EN M-SN B-SE B-EN B-SN)

;; Stage maps operate directly on controls and retained frame payloads. They
;; never plug a whole source term, decompose a decoded term, run a machine,
;; or route S/N through E. The S prefix follows ancestor Owners only.
(define (map-S-frame frame prefix map-control map-goal)
  (match-define (Frame kind before after owners) frame)
  (define here (if owners (owners-support owners prefix) prefix))
  (values
   (match kind
     ['merge-left
      (match-define (list right) after)
      (Frame kind '(mplus) (list (map-control right here)) #f)]
     ['merge-right
      (match-define (list 'mplus _ left) before)
      (Frame kind (list 'mplus (map-control left here)) '() #f)]
     ['bind
      (match-define (list goal) after)
      (Frame kind '(bind) (list (map-goal goal here)) #f)]
     [(or 'yield 'emit)
      (match-define (list constructor _ `(Answer ,head-owners ,state)) before)
      (match-define `(One ,mapped-state) (map-control `(One ,head-owners ,state) here))
      (Frame kind (list constructor mapped-state) '() #f)]
     ['forced (Frame kind '(Forced) '() #f)]
     [(or 'force 'render 'commit 'advance 'collect) (Frame kind before after #f)]
     [_ (raise-argument-error 'map-S-frame "strict S frame" frame)])
   here))

(define (map-S-frames frames prefix map-control map-goal)
  (match frames
    ['() (values '() prefix)]
    [(cons frame rest)
     (define-values (mapped-rest outer) (map-S-frames rest prefix map-control map-goal))
     (define-values (mapped-frame here) (map-S-frame frame outer map-control map-goal))
     (values (cons mapped-frame mapped-rest) here)]))

(define (map-S-continuation continuation prefix map-control map-goal)
  (match continuation
    ['halt (values 'halt prefix)]
    [(K frame rest)
     (define-values (mapped-rest outer)
       (map-S-continuation rest prefix map-control map-goal))
     (define-values (mapped-frame here) (map-S-frame frame outer map-control map-goal))
     (values (K mapped-frame mapped-rest) here)]))

(define (map-S-state configuration map-control map-goal)
  (match configuration
    [(DFinal value) (DFinal (map-control value '()))]
    [(D control frames)
     (define-values (mapped-frames prefix) (map-S-frames frames '() map-control map-goal))
     (D (map-control control prefix) mapped-frames)]
    [(Z control frames)
     (define-values (mapped-frames prefix) (map-S-frames frames '() map-control map-goal))
     (Z (map-control control prefix) mapped-frames)]
    [(M control continuation)
     (define-values (mapped-continuation prefix)
       (map-S-continuation continuation '() map-control map-goal))
     (M (map-control control prefix) mapped-continuation)]
    [(BRun control continuation)
     (define-values (mapped-continuation prefix)
       (map-S-continuation continuation '() map-control map-goal))
     (BRun (map-control control prefix) mapped-continuation)]
    [(BFinal value) (BFinal (map-control value '()))]))

;; E's frame goals are addressed by the support common to the worlds of the
;; current focused computation. Accumulating those worlds through frames is
;; structural: each Yield head/choice sibling retains its OWN support. Their
;; union is never made into a fictitious shared allocation world.
(define (shared-prefix left right)
  (match* (left right)
    [((cons a d) (cons b e)) (if (equal? a b) (cons a (shared-prefix d e)) '())]
    [(_ _) '()]))

(define (world-prefix worlds)
  (match worlds
    ['() '()]
    [(cons first rest) (foldl shared-prefix first rest)]))

(define (map-E-frame frame worlds)
  (match-define (Frame kind before after _) frame)
  (match kind
    ['merge-left
     (match-define (list right) after)
     (values (Frame kind '(mplus) (list (q:Q-EN right)) #f)
             (append worlds (q:world-supports right)))]
    ['merge-right
     (match-define (list 'mplus left) before)
     (values (Frame kind (list 'mplus (q:Q-EN left)) '() #f)
             (append (q:world-supports left) worlds))]
    ['bind
     (match-define (list goal) after)
     (values (Frame kind '(bind) (list (address-goal goal (world-prefix worlds))) #f) worlds)]
    [(or 'yield 'emit)
     (match-define (list constructor state) before)
     (define support (q:state-support state))
     (values (Frame kind (list constructor (address-state state support)) '() #f)
             (cons support worlds))]
    [(or 'force 'render 'forced 'commit 'advance 'collect)
     (values (Frame kind before after #f) worlds)]
    [_ (raise-argument-error 'map-E-frame "strict E frame" frame)]))

(define (map-E-frames frames worlds)
  (match frames
    ['() '()]
    [(cons frame rest)
     (define-values (mapped-frame outer-worlds) (map-E-frame frame worlds))
     (cons mapped-frame (map-E-frames rest outer-worlds))]))

(define (map-E-continuation continuation worlds)
  (match continuation
    ['halt 'halt]
    [(K frame rest)
     (define-values (mapped-frame outer-worlds) (map-E-frame frame worlds))
     (K mapped-frame (map-E-continuation rest outer-worlds))]))

(define (map-E-state configuration)
  (match configuration
    [(DFinal value) (DFinal (q:Q-EN value))]
    [(D control frames)
     (D (q:Q-EN control) (map-E-frames frames (q:world-supports control)))]
    [(Z control frames)
     (Z (q:Q-EN control) (map-E-frames frames (q:world-supports control)))]
    [(M control continuation)
     (M (q:Q-EN control) (map-E-continuation continuation (q:world-supports control)))]
    [(BRun control continuation)
     (BRun (q:Q-EN control) (map-E-continuation continuation (q:world-supports control)))]
    [(BFinal value) (BFinal (q:Q-EN value))]))

(define-syntax-rule (define-stage-maps SE EN SN predicate)
  (begin
    (define (SE configuration)
      (unless (predicate configuration) (raise-argument-error 'SE "matching stage state" configuration))
      (map-S-state configuration q:Q-SE (lambda (goal _) goal)))
    (define (EN configuration)
      (unless (predicate configuration) (raise-argument-error 'EN "matching stage state" configuration))
      (map-E-state configuration))
    (define (SN configuration)
      (unless (predicate configuration) (raise-argument-error 'SN "matching stage state" configuration))
      (map-S-state configuration q:Q-SN address-goal))))

(define-stage-maps D-SE D-EN D-SN (lambda (v) (or (D? v) (DFinal? v))))
(define-stage-maps Z-SE Z-EN Z-SN Z?)
(define-stage-maps M-SE M-EN M-SN M?)
(define-stage-maps B-SE B-EN B-SN (lambda (v) (or (BRun? v) (BFinal? v))))
