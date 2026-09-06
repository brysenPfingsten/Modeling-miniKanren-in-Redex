#lang racket
(require rackunit "anf-tests.rkt" "strictness-tests.rkt" "../test-support/witnesses.rkt"
         "incremental-tests.rkt" "partial-oracle.rkt" "../test-support/frontiers.rkt"
         "03-data.rkt" "derive.rkt"
         (prefix-in d: "03-defunc.rkt")
         (prefix-in m: "04-machine.rkt") (prefix-in r: "05-registers.rkt"))
(provide data-only?)

;; Inspect the entire reachable representation, including saved siblings and
;; nested Delay bodies. A green final frontier alone would miss host closures.
(define (data-only? value)
  (cond
    [(procedure? value) #f]
    [(pair? value) (and (data-only? (car value)) (data-only? (cdr value)))]
    [(vector? value) (for/and ([field (in-vector value)]) (data-only? field))]
    [(struct? value) (data-only? (struct->vector value))]
    [else #t]))

;; Active Search can contain intermediate answers and suspended conjunction
;; work. It is disjoint from settled Frontier even after defunctionalization.
(define (active-search? value)
  (match value
    [`(Empty ,_) #t]
    [`(One ,_ ,_) #t]
    [`(Yield ,_ (Answer ,_ ,_) ,rest) (active-search? rest)]
    [`(Delay ,_ ,resume) (active-resumption? resume)]
    [_ #f]))

(define (active-resumption? value)
  (match value
    [(REval _ _ _) #t]
    [(RMerge right left _) (and (active-search? right) (active-search? left))]
    [(RBind resume (GRight _) _) (active-resumption? resume)]
    [_ #f]))

(define (settled-frontier? value)
  (match value
    [`(Done ,_) #t]
    [`(Last (Owners) (Answer ,_ ,_)) #t]
    [`(Emit ,_ (Answer ,_ ,_) ,rest) (settled-frontier? rest)]
    [`(Forced ,_ ,rest) (settled-frontier? rest)]
    [`(More ,(and delay `(Delay ,_ ,_))) (active-search? delay)]
    [_ #f]))

(define (emits-in value [found '()])
  (match value
    [`(Emit ,owners ,answer ,rest)
     (emits-in rest (emits-in answer (emits-in owners (cons value found))))]
    [(cons first rest) (emits-in rest (emits-in first found))]
    [(? struct?) (emits-in (struct->vector value) found)]
    [(? vector?)
     (for/fold ([found found]) ([field (in-vector value)]) (emits-in field found))]
    [_ found]))

(define (check-domain current)
  (match current
    [(m:Halted value) (check-true (settled-frontier? value))]
    [(m:Call 'merge/d (list left right _ _ _))
     (check-true (active-search? left) "merge left is active Search")
     (check-true (active-search? right) "merge right is active Search")]
    [(m:Call 'bind/d (list search _ _ _ _))
     (check-true (active-search? search) "core bind never consumes settled Emit")]
    [(m:Call (or 'force/d 'commit/d) (list search _))
     (check-true (active-search? search) "force and commit receive active Search")]
    [(m:Call 'resume/d (list resume _))
     (check-true (active-resumption? resume))]
    [(m:Call (or 'advance/d 'collect/d) (list frontier _))
     (check-true (settled-frontier? frontier) "public consumers receive settled Frontier")]
    [_ (void)]))

(define (check-emit-transition before after)
  (define existing (emits-in before))
  (define new-emits
    (filter (lambda (value) (not (member value existing))) (emits-in after)))
  (unless (null? new-emits)
    ;; The consumer frames only rebuild a prefix already settled on entry.
    ;; Creating a new answer's Emit belongs to commit, never core evaluation,
    ;; merge, bind, or invocation of an unfinished Search resumption.
    (check-true
     (match before
       [(m:Call 'commit/d _) #t]
       [(m:Call 'return/d
                (list _ (or (KCommitEmit _ _ _)
                            (KAdvanceEmit _ _ _)
                            (KCollectEmit _ _ _)))) #t]
       [_ #f])
     "settled Emit is constructed only by commit or preserved-prefix reconstruction")))

(define (check-register-trace current bank [fuel 100000])
  (check-true (data-only? current))
  (check-domain current)
  (check-equal? (r:decode bank) current)
  (match current
    [(m:Halted value)
     (check-false (m:step current))
     (check-false (r:step! bank))
     value]
    [_
     (when (zero? fuel) (error 'check-register-trace "fuel exhausted"))
     (define next (m:step current))
     (check-emit-transition current next)
     (check-true (r:step! bank))
     (check-register-trace next bank (sub1 fuel))]))

(define (check-call initial)
  (check-register-trace initial (r:from-machine initial)))

(define (check-before-commit current [fuel 100000])
  (check-equal? (emits-in current) '() "no settled Emit exists before the first commit")
  (match current
    [(m:Call 'commit/d _) (void)]
    [(m:Call _ _)
     (when (zero? fuel) (error 'check-before-commit "no commit within fuel"))
     (check-before-commit (m:step current) (sub1 fuel))]
    [_ (error 'check-before-commit "normal run halted without its commit boundary")]))

(define (check-resumptions frontier [fuel 1000])
  (when (zero? fuel) (error 'check-resumptions "boundary fuel exhausted"))
  ;; Include collection of already observed history, not just fresh run output.
  (void (check-call (m:Call 'collect/d (list frontier (KDone)))))
  (define next (check-call (m:Call 'advance/d (list frontier (KDone)))))
  (if (pending? frontier)
      (check-resumptions next (sub1 fuel))
      (check-equal? next frontier)))

(module+ test
  (check-true (check-generated!))
  (compare-runners d:run d:collect-all m:run m:collect-all)
  (compare-runners m:run m:collect-all r:run r:collect-all)
  (check-strict-runner 'defunctionalized d:run d:collect-all)
  (check-strict-runner 'machine m:run m:collect-all)
  (check-strict-runner 'registers r:run r:collect-all)
  (check-incremental-runner 'machine m:run m:resume-once m:collect-all)
  (check-incremental-runner 'registers r:run r:resume-once r:collect-all)
  (for ([w (in-list validation-witnesses)])
    (define initial
      (m:initial (witness-goal w) #:owners (witness-owners w)
                 #:state (witness-state w)))
    (check-before-commit initial)
    (define frontier (check-call initial))
    (check-resumptions frontier))
  ;; The new failures/suspensions exercise the exact mistake that would make
  ;; an intermediate successful Search answer appear prematurely settled.
  (define temporary-owner '(Owners (Owner (u:0) (label "temporary-owner"))))
  (define failure-witness
    (findf (lambda (w) (eq? (witness-name w) 'intermediate-success-then-failure))
           validation-witnesses))
  (check-equal? (m:run (witness-goal failure-witness)) `(Done ,temporary-owner))
  (define settled '(Emit (Owners) (Answer (Owners) (state () () () (label "settled")))
                         (Done (Owners))))
  (check-false (active-search? settled))
  (check-exn exn:fail?
             (lambda ()
               (m:step (m:Call 'bind/d
                               (list settled (GRight '(succeed (label "bad")))
                                     '(Owners) '() (KDone))))))
  (check-exn exn:fail?
             (lambda ()
               (r:step! (r:from-machine
                         (m:Call 'bind/d
                                 (list settled (GRight '(succeed (label "bad")))
                                       '(Owners) '() (KDone)))))))
  ;; Native producers instantiate the same primitive equations with data
  ;; constructors. No hidden functional result may survive in a partial value.
  (check-true (data-only? (atomic/data '(fail (label "f"))
                                     '(state () () () (label "initial")))))
  (check-true (data-only? (atomic/data '(succeed (label "s"))
                                     '(state () () () (label "initial"))))))
