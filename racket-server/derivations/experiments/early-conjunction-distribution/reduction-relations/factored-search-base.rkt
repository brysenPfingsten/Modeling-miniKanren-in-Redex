#lang racket

(require redex/reduction-semantics
         (prefix-in delay: "../../dormant-branch-semantics/source/reduction-relations/delay-red.rkt")
         (prefix-in disj: "../../dormant-branch-semantics/source/reduction-relations/disj-base-red.rkt"))

(provide work/nonchoice/raw
         work/choice/raw
         work/raw
         frontier/raw
         allocate/base
         work/base
         frontier/base)

(check-redundancy #t)

(require "../../dormant-branch-semantics/source/languages/search-lang.rkt")

;; Experiment-only assembly of the old factored raw rules. The disjunction
;; seam supplies one inherited core copy; Delay adds only its deltas. The
;; distributed relations re-close these rules under their Early* contexts.
(define work/nonchoice/raw
  (union-reduction-relations
   (extend-reduction-relation disj:work/nonchoice/raw search-lang)
   (extend-reduction-relation delay:work/delta/raw search-lang)))

(define work/choice/raw
  (extend-reduction-relation disj:work/choice/delta/raw search-lang))

(define work/raw
  (union-reduction-relations
   work/nonchoice/raw
   work/choice/raw))

(define frontier/raw
  (union-reduction-relations
   (extend-reduction-relation disj:frontier/raw search-lang)
   (extend-reduction-relation delay:frontier/delta/raw search-lang)))

(define allocate/base
  (extend-reduction-relation disj:allocate/base search-lang))

(define work/base
  (context-closure work/raw search-lang WorkFocus))

(define frontier/base
  (context-closure frontier/raw search-lang SpineContext))
