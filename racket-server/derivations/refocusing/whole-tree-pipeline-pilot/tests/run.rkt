#lang racket

(require rackunit/text-ui
         "./source-tests.rkt")

(exit (if (zero? (run-tests source-tests)) 0 1))
