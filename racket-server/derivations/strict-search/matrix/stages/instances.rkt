#lang racket

(require redex/reduction-semantics
         "../../shared/stages/schema.rkt"
         "../../shared/stages/views.rkt"
         "../../shared/kernel.rkt"
         (prefix-in f: "../features.rkt")
         (prefix-in s: "../source-s.rkt")
         (prefix-in e: "../source-e.rkt")
         (prefix-in n: "../source-n.rkt"))

(provide S E N SCore ECore NCore SDelay EDelay NDelay
         SDisjunction EDisjunction NDisjunction s-view e-view n-view)

(define-S-view s-view s:StrictS s:s-value? s:s-frontier?)
(define-ownerless-view e-view e:StrictE e:e-value? e:e-frontier?)
(define-ownerless-view n-view n:StrictN n:n-value? n:n-frontier?)

(define-S-view s-core-view f:StrictSCore f:s-core-value? f:s-core-frontier?)
(define-S-view s-delay-view f:StrictSDelay f:s-delay-value? f:s-delay-frontier?)
(define-S-view s-disjunction-view f:StrictSDisjunction f:s-disjunction-value? f:s-disjunction-frontier?)
(define-ownerless-view e-core-view f:StrictECore f:e-core-value? f:e-core-frontier?)
(define-ownerless-view e-delay-view f:StrictEDelay f:e-delay-value? f:e-delay-frontier?)
(define-ownerless-view e-disjunction-view f:StrictEDisjunction f:e-disjunction-value? f:e-disjunction-frontier?)
(define-ownerless-view n-core-view f:StrictNCore f:n-core-value? f:n-core-frontier?)
(define-ownerless-view n-delay-view f:StrictNDelay f:n-delay-value? f:n-delay-frontier?)
(define-ownerless-view n-disjunction-view f:StrictNDisjunction f:n-disjunction-value? f:n-disjunction-frontier?)

(define (extend-owner-support prefix owners)
  (if owners (owners-support owners prefix) prefix))

(define (preserve-support prefix _) prefix)

(define S (Stage 'Search/S s:s-contract s-view extend-owner-support))
(define E (Stage 'Search/E e:e-contract e-view preserve-support))
(define N (Stage 'Search/N n:n-contract n-view preserve-support))
(define SCore (Stage 'Core/S f:s-core-contract s-core-view extend-owner-support))
(define ECore (Stage 'Core/E f:e-core-contract e-core-view preserve-support))
(define NCore (Stage 'Core/N f:n-core-contract n-core-view preserve-support))
(define SDelay (Stage 'Delay/S f:s-delay-contract s-delay-view extend-owner-support))
(define EDelay (Stage 'Delay/E f:e-delay-contract e-delay-view preserve-support))
(define NDelay (Stage 'Delay/N f:n-delay-contract n-delay-view preserve-support))
(define SDisjunction (Stage 'Disjunction/S f:s-disjunction-contract s-disjunction-view extend-owner-support))
(define EDisjunction (Stage 'Disjunction/E f:e-disjunction-contract e-disjunction-view preserve-support))
(define NDisjunction (Stage 'Disjunction/N f:n-disjunction-contract n-disjunction-view preserve-support))
