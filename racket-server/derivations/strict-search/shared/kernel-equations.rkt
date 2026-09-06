#lang racket

(require redex/reduction-semantics
         (prefix-in s: "core/s/language.rkt"))
(provide define-kernel current-atomic-observer)

;; Test instrumentation is outside the semantic configurations.
(define current-atomic-observer (make-parameter (lambda (_goal _state) (void))))

;; The preserved S primitive equations, with their two result producers
;; explicit. Instantiation changes those producers at defunctionalization;
;; there is never a functional-result-to-data runtime adapter.
(define-syntax-rule (define-kernel name failure success)
  (define (name goal state)
    ((current-atomic-observer) goal state)
    (match-define `(state ,sub ,dis ,trail ,tag) state)
    (match goal
      [`(succeed ,_) (success state)]
      [`(fail ,_) (failure)]
      [`(,left =? ,right ,_)
       (define next
         (term (s:unify/s (s:walk/s ,left ,sub) (s:walk/s ,right ,sub) ,sub)))
       (if (and next (not (term (s:invalid?/s ,next ,dis))))
           (success `(state ,next ,dis ,(append trail (list goal)) ,tag))
           (failure))]
      [`(,left != ,right ,_)
       (define next-dis (cons (list left right) dis))
       (if (term (s:invalid?/s ,sub ,next-dis))
           (failure)
           (success `(state ,sub ,next-dis ,trail ,tag)))]
      [_ (raise-argument-error 'name "no-relcall S atomic goal" goal)])))
