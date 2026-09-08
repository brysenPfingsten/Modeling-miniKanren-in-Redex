#lang racket

(require rackunit json racket/runtime-path "../source/inspection.rkt")

(define-runtime-path contract-path "../../../../../contracts/visible-node-contract.json")
(define allowed-names
  (hash-ref (call-with-input-file contract-path read-json) 'visibleNodeNames))
(define empty-state '(state () () () (label "initial")))
(define yes '(succeed (label "yes")))
(define no '(fail (label "no")))

(define (nodes picture)
  (cons picture (append-map nodes (hash-ref picture 'children '()))))

(define (named picture name)
  (filter (lambda (node) (equal? (hash-ref node 'name) name)) (nodes picture)))

(define (check-picture configuration [queries '()])
  (define picture (cfg->operational-picture configuration queries))
  (check-true (jsexpr? picture))
  (for ([part (in-list (nodes picture))])
    (check-not-false (member (hash-ref part 'name) allowed-names))
    (when (hash-has-key? part 'activeChildIndex)
      (check-true (< (hash-ref part 'activeChildIndex)
                    (length (hash-ref part 'children))))))
  picture)

(module+ test
  (test-case "historical lattice orientation selects a child without committing returned work"
    (define owners '(Owners (Owner (u:9) (label "query"))))
    (define state '(state ((u:9 (sym "a"))) () () (label "candidate")))
    (for ([orientation '(DisjL DisjR)] [active '(0 1)] [name '("<-+" "+->")])
      (define configuration
        `(() (More (,orientation ,owners
                      (Returned (Owners) ,state)
                      (Conj (Owners) (Work (Owners) ,yes ,state) ,no)))))
      (define picture (check-picture configuration '(u:9)))
      (define choice (car (named picture name)))
      (check-equal? (hash-ref choice 'activeChildIndex) active)
      (check-equal? (hash-ref picture 'renderRole) "unfinished-frontier")
      (check-equal? (hash-ref picture 'activeChildIndex) 0)
      (check-equal? (length (named picture "Returned")) 1)
      (check-equal? (length (named picture "Candidate")) 1)
      (check-equal? (length (named picture "Conjunction")) 1)
      (check-equal? (named picture "Answer") '())
      (check-equal? (committed-answer-nodes configuration '(u:9)) '())
      (check-equal? (hash-ref (car (named picture "Work")) 'scope) '(9))))

  (test-case "lattice delay keeps retained work suspended and outer answers committed"
    (define common '(Owners (Owner () (label "unused")) (Owner (u:9) (label "common"))))
    (define state '(state ((u:9 (sym "a"))) () () (label "answer")))
    (define configuration
      `(() (Emit ,common
             (Answer (Owners (Owner (u:2) (label "private"))) ,state)
             (More (PendingDelay (Owners (Owner (u:3) (label "delayed")))
                     (DisjR (Owners)
                       (Work (Owners) ,yes ,state)
                       (Work (Owners) ,no ,state)))))))
    (define picture (check-picture configuration '(u:9)))
    (define paused (car (named picture "More")))
    (define delay (car (named picture "Delay")))
    (check-equal? (hash-ref paused 'renderRole) "paused-frontier")
    (check-false (hash-has-key? paused 'activeChildIndex))
    (check-false (hash-has-key? delay 'activeChildIndex))
    (check-true (hash-ref delay 'suspended))
    (check-equal? (map (lambda (node) (hash-ref node 'scope)) (named picture "Work"))
                  '((9 3) (9 3)))
    (check-equal? (map (lambda (node) (hash-ref node 'scope))
                       (committed-answer-nodes configuration '(u:9))) '((9 2)))
    (check-equal? (map (lambda (node) (hash-ref node 'id)) (named picture "Freshened"))
                  '("unused" "common" "private" "delayed"))
    (check-equal? (hash-ref (check-picture '(() (More (Dead (Owners))))) 'renderRole)
                  "unfinished-frontier"))

)
