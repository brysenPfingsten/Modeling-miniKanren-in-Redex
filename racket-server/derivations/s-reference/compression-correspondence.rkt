#lang racket

(require (prefix-in checkpoint: "machine.rkt")
         (prefix-in register: "registers.rkt")
         (prefix-in compressed: "compressed.rkt")
         (only-in "machine-correspondence.rkt" functional-step-label))
(provide (struct-out OriginalStep)
         (rename-out [compressed:decode compressed->functional])
         compressed->registers compressed-step-span)

;; Each descriptor names one old transition, including its operation label.
;; pcs is a nonempty list of allowed source controls. Only the third edge of an
;; atomic span has two possibilities, determined by the actual kernel outcome.
;; Computing the descriptor never evaluates the atom or takes a machine step.
(struct OriginalStep (pcs label) #:transparent)

;; These maps copy/inspect register fields only. Every compressed configuration
;; is already a checkpoint configuration at a retained control point. There is
;; no normalization or simulation in either representation map.
(define (compressed->registers current)
  (register:from-machine (compressed:decode current)))

(define (compressed-step-span current)
  (define original (compressed:decode current))
  (match original
    [(checkpoint:Halted _) '()]
    [(checkpoint:Call pc _)
     (define label (functional-step-label original))
     (if (equal? label "eval-atom")
         (list (OriginalStep '(eval/d) "eval-atom")
               (OriginalStep '(outcome/d) #f)
               (OriginalStep '(failure/d success/d) #f))
         (list (OriginalStep (list pc) label)))]))

;; Span length is fixed before stepping: three for eval-atom, one for every
;; other active control, zero at Halted. Thus matching never searches ahead.
;; The removed suffix is outcome/d -> failure|success/d -> return/d, with rank
;; 2 -> 1 -> 0. No return continuation is dispatched by this compression and no
;; semantic boundary, including commitment or either kind of forcing, moves.
