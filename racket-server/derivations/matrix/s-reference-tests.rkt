#lang racket

(require rackunit redex/reduction-semantics
         "source-s.rkt" "source-e.rkt" "source-n.rkt"
         "stages/instances.rkt"
         "../shared/stages/schema.rkt" "../shared/stages/maps.rkt"
         "../shared/maps.rkt" "../shared/wf.rkt"
         (only-in "../shared/kernel.rkt" owners-support)
         "../shared/feature-schema.rkt"
         "../test-support/witnesses.rkt" "../test-support/frontiers.rkt"
         (only-in "../s-reference/data.rkt" KDone)
         "../s-reference/source.rkt" "../s-reference/stages.rkt"
         "../s-reference/machine-correspondence.rkt"
         "../s-reference/administration.rkt"
         (only-in "../s-reference/readback.rkt"
                  reify-frontier readback-call readback-halted)
         (prefix-in f: "../s-reference/machine.rkt"))

;; This is a validation dependency on the independently stated S checkpoint.
;; Matrix execution never imports the functional machine or its transitions.
;; Each functional semantic edge prescribes one native source contraction,
;; followed only by structurally classified context administration. No runner
;; searches for a matching target or crosses a public Frontier to find one.
(define observed-labels (make-hash))

(define (whole-readback configuration)
  (match configuration
    [(f:Call pc operands) (readback-call pc operands)]
    [(f:Halted value) (readback-halted value)]))

(define (normalize stage configuration [reversed '()] [fuel 10000])
  (cond
    [(m-admin? stage configuration)
     (when (zero? fuel) (error 'normalize "administrative budget exhausted"))
     (match-define (list "admin" next) (m-step stage configuration))
     (check-equal? (readback-M configuration) (readback-M next))
     (normalize stage next (cons "admin" reversed) (sub1 fuel))]
    [else (values configuration (reverse reversed))]))

(define (compressed stage configuration)
  (match-define (M control continuation) configuration)
  (if (m-final? stage configuration)
      (BFinal control)
      (BRun control continuation)))

;; Equal whole R successors and equal native stage edges are stronger than
;; endpoint agreement. This includes all controls, retained contexts, labels,
;; and B's exact original transition spans, including halted More(Delay).
(define (check-independent-s-stages source)
  (for ([operations
         (in-list (list (list decompose d-step d-trace readback-D)
                        (list initial-Z z-step z-trace readback-Z)
                        (list initial-M m-step m-trace readback-M)
                        (list initial-B b-step b-trace readback-B)))])
    (match-define (list initial step trace readback) operations)
    (define start (initial RetainedS source))
    (check-equal? start (initial S source))
    (for ([configuration (in-list (cons start (map second (trace RetainedS start))))])
      (check-equal? (step S configuration) (step RetainedS configuration))
      (define whole (readback configuration))
      (check-equal?
       (apply-reduction-relation/tag-with-names strict-s-red whole)
       (apply-reduction-relation/tag-with-names retained-red whole)))))

(define (check-functional-path current references [fuel 100000])
  (when (zero? fuel) (error 'check-functional-path "functional budget exhausted"))
  (define mapped (functional->M current))
  (define whole (whole-readback current))
  (check-equal? (readback-M mapped) whole)
  (check-equal? (M-EN (M-SE mapped)) (M-SN mapped))
  (define maps (list values M-SE M-SN))
  (define source-maps (list values Q-SE Q-SN))
  (for ([stage (in-list (list S E N))]
        [map-state (in-list maps)]
        [map-source (in-list source-maps)]
        [wf? (in-list (list wf-s? wf-e? wf-n?))]
        [reference (in-list references)])
    (define-values (normal _labels) (normalize stage (map-state mapped)))
    (check-equal? normal reference)
    (check-equal? (readback-M reference) (map-source whole))
    (check-true (wf? (readback-M reference))))
  (match current
    [(f:Halted value)
     (for ([stage (in-list (list S E N))]
           [map-source (in-list source-maps)]
           [reference (in-list references)])
       (check-equal? reference (M (map-source (reify-frontier value)) 'halt))
       (check-true (m-final? stage reference))
       (check-false (m-step stage reference))
       (check-false (b-step stage (compressed stage reference))))
     value]
    [_
     (define expected (functional-step-label current))
     (hash-set! observed-labels expected #t)
     (define next (f:step current))
     (define next-mapped (functional->M next))
     (define next-whole (whole-readback next))
     (unless expected
       (check-true (< (functional-admin-rank next) (functional-admin-rank current)))
       (check-equal? whole next-whole))
     (define next-references
       (for/list ([stage (in-list (list S E N))]
                  [relation (in-list (list strict-s-red strict-e-red strict-n-red))]
                  [map-state (in-list maps)]
                  [map-source (in-list source-maps)]
                  [reference (in-list references)])
         (define-values (target _target-labels) (normalize stage (map-state next-mapped)))
         (cond
           [expected
            (check-equal?
             (apply-reduction-relation/tag-with-names relation (map-source whole))
             (list (list expected (map-source next-whole))))
            (match-define (list label native-next) (m-step stage reference))
            (check-equal? label expected)
            (define-values (normal labels) (normalize stage native-next))
            (check-equal? normal target)
            ;; B executes its own residual dispatcher. Its exact certificate
            ;; must describe this prescribed M contraction and admin suffix.
            (match-define (list span b-next) (b-step stage (compressed stage reference)))
            (check-equal? (Span-labels span) (cons expected labels))
            (check-equal? (decode-BM b-next) normal)
            (check-equal? (replay-span stage reference span) normal)
            normal]
           [else
            (check-equal? reference target)
            reference])))
     (check-functional-path next next-references (sub1 fuel))]))

(define (check-operation initial source)
  (check-equal? (whole-readback initial) source)
  (check-independent-s-stages source)
  (define references
    (for/list ([stage (in-list (list S E N))]
               [map-source (in-list (list values Q-SE Q-SN))])
      (define-values (reference labels) (normalize stage (initial-M stage (map-source source))))
      (check-equal? labels '())
      reference))
  (check-functional-path initial references))

(define (check-boundaries frontier [fuel 100])
  (when (zero? fuel) (error 'check-boundaries "unexpected productive fixture exhaustion"))
  (define native (reify-frontier frontier))
  (define collected
    (check-operation (f:Call 'collect/d (list frontier '() (KDone))) `(collect ,native)))
  (check-true (s-observation? (reify-frontier collected)))
  (define advanced
    (check-operation (f:Call 'advance/d (list frontier '() (KDone))) `(advance ,native)))
  (cond
    [(pending? frontier) (check-boundaries advanced (sub1 fuel))]
    [else (check-equal? advanced frontier) (check-equal? collected frontier)]))

(define initial-state '(state () () () (label "initial")))
(define yes '(succeed (label "yes")))
(define no '(fail (label "no")))

;; Local Delay ownership is exercised under each data resumption family,
;; including repeated bind resumes, nested force orientation, unused Owners,
;; and fresh work whose answer-private supply must not affect its sibling.
(define owned-goals
  (for/list ([body (in-list
                   (list yes no `(,yes ∨ ,yes (label "more"))
                         `(,no ∨ ,yes (label "reuse-right"))
                         `(suspend ,yes (label "inner"))
                         '(∃ (x:y) (x:y =? x:x (label "alias")) (label "fresh-y"))
                         `(,no ∧ (suspend ,yes (label "unreachable")) (label "failed-bind"))
                         `((suspend ,yes (label "bind-delay"))
                           ∧ ,yes (label "resumed-bind"))
                         `(((suspend ,yes (label "nested-bind-delay"))
                            ∧ ,yes (label "inner-bind"))
                           ∧ ,yes (label "outer-bind"))))])
    `((∃ (x:x x:unused) (suspend ,body (label "pause")) (label "fresh-x"))
      ∨ ,no (label "choice"))))

(module+ test
  (for ([sample (in-list
                 (append validation-witnesses
                         (for/list ([goal (in-list owned-goals)] [index (in-naturals)])
                           (witness (string->symbol (format "owned-resumption-~a" index))
                                    goal '(Owners) initial-state "internal scope resumption"))))])
    (test-case (format "selected functional machine and native S/E/N transitions: ~a"
                       (witness-name sample))
      (define frontier
        (check-operation
         (f:initial (witness-goal sample) #:owners (witness-owners sample)
                    #:state (witness-state sample))
         `(commit ,(witness-initial sample))))
      (check-boundaries frontier)))

  (test-case "every non-render source operation participates in the widened correspondence"
    (check-true (hash-has-key? observed-labels #f))
    (check-equal? (sort (filter values (hash-keys observed-labels)) string<?)
                  (sort (filter (lambda (label) (not (string-prefix? label "render-")))
                                (feature-labels search)) string<?)))

  (test-case "root lifting is structural support extension including transparent force"
    (define outer '(Owners (Owner (u:9) (label "outer")) (Owner () (label "unused"))))
    (define local '(Owners (Owner (u:2) (label "local"))))
    (define body `(eval ,local (∃ (x:new) ,yes (label "fresh")) ,initial-state))
    (for ([active (in-list
                   (list body
                         `(mplus ,local (One (Owners) ,initial-state)
                                 (eval (Owners) ,yes ,initial-state))
                         `(bind ,local (Delay (Owners) (eval (Owners) ,yes ,initial-state)) ,yes)
                         `(Yield ,local (Answer (Owners) ,initial-state)
                                 (eval (Owners) ,yes ,initial-state))
                         `(force (Delay ,local (eval (Owners) ,yes ,initial-state)))
                         `(force (force (Delay ,local (eval (Owners) ,yes ,initial-state))))))])
      (define lifted (lift-owners/s outer active))
      (check-equal? lifted (lift-owners outer active))
      (check-equal? (Q-SE lifted) (Q-SE active (owners-support outer)))
      (check-equal? (Q-SN lifted) (Q-SN active (owners-support outer)))
      (check-equal? (Q-EN (Q-SE lifted)) (Q-SN lifted)))))
