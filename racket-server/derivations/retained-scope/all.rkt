#lang racket

(require (submod "source-tests.rkt" test)
         (submod "interpreter-tests.rkt" test)
         (submod "defunc-tests.rkt" test)
         (submod "machine-correspondence-tests.rkt" test)
         (submod "register-tests.rkt" test)
         (submod "register-compression-tests.rkt" test)
         (submod "relation-tests.rkt" test))
