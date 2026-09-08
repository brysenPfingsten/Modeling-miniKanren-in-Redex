#lang racket

(require (prefix-in source: "source.rkt")
         (prefix-in map: "lattice-map.rkt"))

;; A concrete, executable version of the diagram in README.md. Both the
;; extended source and native projections below retain the original A/B slots
;; during a Railroad switch; Flip exchanges them.
(define state '(state () () () (label "initial")))
(define (job name) `(eval (Owners) ((sym ,name) =? (sym ,name) (label ,name)) ,state))
(define (show-switch policy)
  (define before `(program ,policy () (commit (mplus (Owners) (Delay (Owners) ,(job "A")) ,(job "B")))))
  (match-define (list label after) (source:step before))
  (printf "~a: ~a -> ~a\n" policy label (map:native-label before label))
  (printf "  source before: ~s\n  source after:  ~s\n"
          before after)
  (printf "  native before: ~s\n  native after:  ~s\n\n"
          (map:source->lattice before) (map:source->lattice after)))

(module+ main
  (for ([policy '(dfs flip rail)]) (show-switch policy))
  (define before `(program flip () (commit (mplus (Owners) (One (Owners) ,state) ,(job "B")))))
  (match-define (list label after) (source:step before))
  (printf "Administrative candidate packaging: ~a\n" label)
  (printf "  before: ~s\n  after:  ~s\n" before after)
  (printf "  identical native image: ~a\n" (equal? (map:source->lattice before) (map:source->lattice after)))
  (printf "  decreasing administrative weight: ~a -> ~a\n"
          (map:administrative-weight before) (map:administrative-weight after)))
