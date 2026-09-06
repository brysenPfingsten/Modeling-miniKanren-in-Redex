#lang racket

(require rackunit
         (prefix-in direct: "../functional-search/direct-interpreter.rkt")
         (prefix-in source: "source.rkt")
         (prefix-in decomposition: "decomposition.rkt")
         (prefix-in refocused: "refocused.rkt")
         (prefix-in machine: "machine.rkt")
         (prefix-in compressed: "compressed.rkt")
         (prefix-in big: "big-step.rkt")
         (prefix-in functional: "functional-machine.rkt")
         (prefix-in registers: "register-machine.rkt"))

;; Exercise the native protocol at every independent evaluator boundary. These
;; callbacks construct result functions directly; no legacy result exists to
;; decode. Their event log distinguishes eager kernel computation from result
;; elimination, and both from an actual Delay resumption.
(define engines
  (list (list 'direct direct:run direct:run-search)
        (list 'R source:run source:run-search)
        (list 'D decomposition:run decomposition:run-search)
        (list 'Z refocused:run refocused:run-search)
        (list 'M machine:run machine:run-search)
        (list 'B compressed:run compressed:run-search)
        (list 'Big big:run big:run-search)
        (list 'CPS functional:cps-run functional:cps-run-search)
        (list 'defunctionalized functional:run functional:run-search)
        (list 'registers registers:run registers:run-search)))

(define (native-goal events)
  (define (record event) (set-box! events (cons event (unbox events))))
  (define (request tag)
    (direct:Atom
     (lambda (state)
       (record `(kernel ,tag))
       (match tag
         ['reject
          (lambda (failure _success)
            (record `(eliminate ,tag))
            (failure))]
         [_
          (define next
            (struct-copy direct:State state
                         [tag tag]
                         [trail (append (direct:State-trail state) (list tag))]))
          (record `(computed ,tag))
          (lambda (_failure success)
            (record `(eliminate ,tag))
            (success next))]))
     tag))
  (direct:Disj
   (request 'reject)
   (direct:Conj (request 'pass)
                (direct:Suspend (request 'resumed) 'delay)
                'then-delay)
   'choice))

(module+ test
  (define initial (direct:State 7 '(old-substitution) '(old-disequality) '(old) 'initial))
  (define eager-events
    '((kernel reject) (eliminate reject)
      (kernel pass) (computed pass) (eliminate pass)))
  (define forced-events
    (append eager-events '((kernel resumed) (computed resumed) (eliminate resumed))))
  (define expected
    (direct:Forced
     (direct:Last
      (direct:Answer
       (struct-copy direct:State initial [tag 'resumed] [trail '(old pass resumed)])))))

  (for ([engine (in-list engines)])
    (match-define (list name run search) engine)
    (test-case (format "~a consumes native outcomes eagerly through forcing" name)
      (define events (box '()))
      (check-equal? (run (native-goal events) #:state initial) expected)
      (check-equal? (reverse (unbox events)) forced-events))
    (test-case (format "~a keeps native kernel work behind object Delay" name)
      (define events (box '()))
      (void (search (native-goal events) #:state initial))
      (check-equal? (reverse (unbox events)) eager-events))))
