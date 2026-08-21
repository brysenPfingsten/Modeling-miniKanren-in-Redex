#lang racket

(require redex/reduction-semantics
         (only-in "../../../../src/search-lattice/reduction-relations/core-red.rkt"
                  core-red)
         "./decomposition.rkt")

(provide source-step/spec/s)

;; This is the deliberately slow specification adapter: rebuild the source
;; frontier, ask the authoritative R[S] relation for its one raw successor,
;; then decompose again.  The direct D[S] module does not import this file or
;; the production relation.
(define (only-source-successor source)
  (match (apply-reduction-relation/tag-with-names core-red source)
    [(list (list name target))
     (list (string->symbol (~a name)) target)]
    [_ #f]))

(define-judgment-form
  core-s-decomposition-lang
  #:contract (source-step/spec/s D RuleName D)
  #:mode (source-step/spec/s I O O)

  [(where (RuleName F_next)
          ,(only-source-successor (term (plug-D/s D))))
   (decompose/s F_next D_next)
   ---------------------------------------------------- "source step transported to D/S"
   (source-step/spec/s D RuleName D_next)])
