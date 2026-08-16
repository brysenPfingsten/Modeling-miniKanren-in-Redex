#lang racket

(require redex/reduction-semantics
         "./language.rkt")

(provide redex-name->label
         label->redex-name)

;; The finite maps are shared derivation data, not an operational dependency on
;; any stage.  A Redex rule name carries both the frozen source name and owner.
(define-metafunction redex-column-source-lang
  redex-name->label : string -> ell
  [(redex-name->label "expose-frontier-fresh/core") (expose-frontier-fresh core)]
  [(redex-name->label "finish-success/core") (finish-success core)]
  [(redex-name->label "finish-failure/core") (finish-failure core)]
  [(redex-name->label "force-delay/delay") (force-delay delay)]
  [(redex-name->label "commit-choice-answer/disj") (commit-choice-answer disj)]
  [(redex-name->label "commit-right-choice-answer/search-join") (commit-right-choice-answer search-join)]
  [(redex-name->label "work-succeed/core") (work-succeed core)]
  [(redex-name->label "work-fail/core") (work-fail core)]
  [(redex-name->label "work-put/core") (work-put core)]
  [(redex-name->label "allocate-fresh/core") (allocate-fresh core)]
  [(redex-name->label "expand-conjunction/core") (expand-conjunction core)]
  [(redex-name->label "expand-disjunction/disj") (expand-disjunction disj)]
  [(redex-name->label "suspend-goal/delay") (suspend-goal delay)]
  [(redex-name->label "expose-choice-through-work-fresh/disj") (expose-choice-through-work-fresh disj)]
  [(redex-name->label "expose-choice-through-work-fresh/search-join") (expose-choice-through-work-fresh search-join)]
  [(redex-name->label "erase-dead-fresh/core") (erase-dead-fresh core)]
  [(redex-name->label "bubble-delay-through-fresh/delay") (bubble-delay-through-fresh delay)]
  [(redex-name->label "conj-return/core") (conj-return core)]
  [(redex-name->label "conj-fail/core") (conj-fail core)]
  [(redex-name->label "bubble-delay-through-conj/delay") (bubble-delay-through-conj delay)]
  [(redex-name->label "late-distribute-settled/disj") (late-distribute-settled disj)]
  [(redex-name->label "late-distribute-right-settled/search-join") (late-distribute-right-settled search-join)]
  [(redex-name->label "skip-left-failure/disj") (skip-left-failure disj)]
  [(redex-name->label "rail-enter-right/search-join") (rail-enter-right search-join)]
  [(redex-name->label "reassociate-left-result/disj") (reassociate-left-result disj)]
  [(redex-name->label "skip-right-failure/search-join") (skip-right-failure search-join)]
  [(redex-name->label "rail-return-left/search-join") (rail-return-left search-join)]
  [(redex-name->label "reassociate-right-result/search-join") (reassociate-right-result search-join)])

(define-metafunction redex-column-source-lang
  label->redex-name : ell -> string
  [(label->redex-name (expose-frontier-fresh core)) "expose-frontier-fresh/core"]
  [(label->redex-name (finish-success core)) "finish-success/core"]
  [(label->redex-name (finish-failure core)) "finish-failure/core"]
  [(label->redex-name (force-delay delay)) "force-delay/delay"]
  [(label->redex-name (commit-choice-answer disj)) "commit-choice-answer/disj"]
  [(label->redex-name (commit-right-choice-answer search-join)) "commit-right-choice-answer/search-join"]
  [(label->redex-name (work-succeed core)) "work-succeed/core"]
  [(label->redex-name (work-fail core)) "work-fail/core"]
  [(label->redex-name (work-put core)) "work-put/core"]
  [(label->redex-name (allocate-fresh core)) "allocate-fresh/core"]
  [(label->redex-name (expand-conjunction core)) "expand-conjunction/core"]
  [(label->redex-name (expand-disjunction disj)) "expand-disjunction/disj"]
  [(label->redex-name (suspend-goal delay)) "suspend-goal/delay"]
  [(label->redex-name (expose-choice-through-work-fresh disj)) "expose-choice-through-work-fresh/disj"]
  [(label->redex-name (expose-choice-through-work-fresh search-join)) "expose-choice-through-work-fresh/search-join"]
  [(label->redex-name (erase-dead-fresh core)) "erase-dead-fresh/core"]
  [(label->redex-name (bubble-delay-through-fresh delay)) "bubble-delay-through-fresh/delay"]
  [(label->redex-name (conj-return core)) "conj-return/core"]
  [(label->redex-name (conj-fail core)) "conj-fail/core"]
  [(label->redex-name (bubble-delay-through-conj delay)) "bubble-delay-through-conj/delay"]
  [(label->redex-name (late-distribute-settled disj)) "late-distribute-settled/disj"]
  [(label->redex-name (late-distribute-right-settled search-join)) "late-distribute-right-settled/search-join"]
  [(label->redex-name (skip-left-failure disj)) "skip-left-failure/disj"]
  [(label->redex-name (rail-enter-right search-join)) "rail-enter-right/search-join"]
  [(label->redex-name (reassociate-left-result disj)) "reassociate-left-result/disj"]
  [(label->redex-name (skip-right-failure search-join)) "skip-right-failure/search-join"]
  [(label->redex-name (rail-return-left search-join)) "rail-return-left/search-join"]
  [(label->redex-name (reassociate-right-result search-join)) "reassociate-right-result/search-join"])

