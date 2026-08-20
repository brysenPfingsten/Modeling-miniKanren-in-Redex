#lang racket

(require rackunit
         rackunit/text-ui
         "../src/program-runner.rkt")

(define mini-same-program
  "(defrel (same x y)
     (== x y))
   (run* (q)
     (same q 'cat))")

(define micro-same-program
  "(run* (q)
     (== q 'cat))")

(define bounded-program
  "(run 2 (q)
     (conde
       [(== q 'a)]
       [(== q 'b)]
       [(== q 'c)]))")

(define diverging-program
  "(defrel (loopo x)
     (loopo x))
   (run* (q)
     (loopo q))")

(define/provide-test-suite PROGRAM-RUNNER
  (test-case "run-source->answers returns reified answers for mini source"
    (check-equal? (run-source->answers mini-same-program)
                  (list (hasheq 'sym "cat"))))

  (test-case "run-source exposes answer nodes and picture for direct micro source"
    (define result
      (run-source micro-same-program
                  #:source-mode "micro"
                  #:search-strategy (search-strategy "flip")))
    (check-equal? (run-result-answers result)
                  (list (hasheq 'sym "cat")))
    (check-true (positive? (run-result-step-count result)))
    (check-equal? (length (run-result-answer-nodes result))
                  1)
    (check-equal? (hash-ref (car (run-result-answer-nodes result)) 'renderRole)
                  "answer-node")
    (check-true (hash? (run-result-picture result))))

  (test-case "run-source->picture preserves reified answers"
    (define picture
      (run-source->picture mini-same-program))
    (define first-child
      (car (hash-ref picture 'children)))
    (define answer-node
      (car (hash-ref first-child 'children)))
    (check-equal? (hash-ref answer-node 'reified)
                  (hasheq 'sym "cat")))

  (test-case "run-source->host-answers returns Racket-shaped answers"
    (check-equal? (run-source->host-answers mini-same-program)
                  '(cat)))

  (test-case "answer-limit stops once enough answers are surfaced"
    (check-equal? (run-source->host-answers bounded-program
                                            #:answer-limit 2)
                  '(a b))
    (check-equal? (run-source->host-answers bounded-program
                                            #:answer-limit 0)
                  '()))

  (test-case "run-source enforces a step cap for diverging programs"
    (check-exn
     (lambda (e)
       (and (exn:fail? e)
            (regexp-match? #rx"step cap" (exn-message e))))
     (lambda ()
       (run-source->answers diverging-program #:step-cap 4)))))

(module+ test
  (run-tests PROGRAM-RUNNER))
