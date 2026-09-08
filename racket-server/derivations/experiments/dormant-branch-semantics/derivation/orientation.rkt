#lang racket

(provide erase-work
         erase-frontier
         rail->flip/config
         rail->flip-label
         rail->flip/named-successors
         rail->flip-label-table)

;; Orientation erasure is a representation map on the native lattice carrier,
;; not an interpreter or a new scheduler. Goals, relation definitions, owners,
;; answers, and logical states are retained literally. In particular, the map
;; does not traverse data inside goals or stores looking for constructor names.
;; Its domain is the well-formed Railroad configuration grammar.
;;
;; Proposed strong-bisimulation relation:
;;   R(rail, flip) iff flip = rail->flip/config(rail).
;; Every source step must correspond to exactly one target step, with the
;; explicit label map below. No normalization or forward search is involved.
;;
;; Proof obligations factor into:
;; 1. Context/plugging: a right-active frame DisjR(O,W,hole) erases to
;;    DisjL(O,hole,erase-work(W)); the other frames commute homomorphically.
;; 2. Root owner attachment commutes with erasure and preserves owner order.
;; 3. Erasure preserves the set of symbols occurring in the complete Frontier,
;;    except DisjR itself. Thus variables-not-in selects identical u: names.
;; 4. The eight oriented clauses erase to the listed left-active clauses; all
;;    shared primitive, conjunction, suspension, and call clauses commute.
;; 5. The same active path and constructor cases reflect target steps, as well
;;    as preserving source steps. Stuck, paused, and completed boundaries agree.
;;
;; orientation-tests.rkt checks both complete successor lists, every native
;; rule, well-formedness, public forcing, and finite/bounded-infinite traces.
;; These checks are finite evidence for the obligations, not a general proof.
;; The relation deliberately forgets branch-position observations: Railroad
;; retains information that the Flip tree expresses by exchanging children.

(define (erase-work work)
  (match work
    [`(Work ,owners ,goal ,state) work]
    [`(Returned ,owners ,state) work]
    [`(Dead ,owners) work]
    [`(Conj ,owners ,body ,goal)
     `(Conj ,owners ,(erase-work body) ,goal)]
    [`(DisjL ,owners ,left ,right)
     `(DisjL ,owners ,(erase-work left) ,(erase-work right))]
    [`(DisjR ,owners ,left ,right)
     `(DisjL ,owners ,(erase-work right) ,(erase-work left))]
    [`(PendingDelay ,owners ,body)
     `(PendingDelay ,owners ,(erase-work body))]
    [_ (raise-argument-error 'erase-work "native Railroad work" work)]))

(define (erase-frontier frontier)
  (match frontier
    [`(Done ,owners) frontier]
    [`(Last ,owners ,answer) frontier]
    [`(Emit ,owners ,answer ,rest)
     `(Emit ,owners ,answer ,(erase-frontier rest))]
    [`(Forced ,owners ,rest)
     `(Forced ,owners ,(erase-frontier rest))]
    [`(More ,work) `(More ,(erase-work work))]
    [_ (raise-argument-error 'erase-frontier "native Railroad Frontier" frontier)]))

(define (rail->flip/config configuration)
  (match configuration
    [`(,definitions ,frontier)
     `(,definitions ,(erase-frontier frontier))]
    [_ (raise-argument-error 'rail->flip/config
                             "native (Gamma Frontier) configuration"
                             configuration)]))

;; Listing shared labels as well makes extension of either native relation an
;; explicit audit point. Unknown names cannot silently pass through the map.
(define rail->flip-label-table
  '(("expand-conjunction" . "expand-conjunction")
    ("succeed" . "succeed")
    ("fail" . "fail")
    ("conj-return" . "conj-return")
    ("conj-fail" . "conj-fail")
    ("unify-success" . "unify-success")
    ("unify-violates-disequality" . "unify-violates-disequality")
    ("unify-fail" . "unify-fail")
    ("disequality-success" . "disequality-success")
    ("disequality-fail" . "disequality-fail")
    ("finish-success" . "finish-success")
    ("finish-failure" . "finish-failure")
    ("allocate-fresh" . "allocate-fresh")
    ("expand-disjunction" . "expand-disjunction")
    ("skip-left-failure" . "skip-left-failure")
    ("reassociate-left-result" . "reassociate-left-result")
    ("commit-choice-answer" . "commit-choice-answer")
    ("resume-left-choice-success" . "resume-left-choice-success")
    ("suspend-goal" . "suspend-goal")
    ("bubble-delay-through-conj" . "bubble-delay-through-conj")
    ("force-delay" . "force-delay")
    ("expand-relcall" . "expand-relcall")
    ("skip-right-failure" . "skip-left-failure")
    ("reassociate-left-result/search-join" . "reassociate-left-result")
    ("reassociate-right-result/left-nested" . "reassociate-left-result")
    ("reassociate-right-result/right-nested" . "reassociate-left-result")
    ("resume-right-choice-success" . "resume-left-choice-success")
    ("commit-right-choice-answer" . "commit-choice-answer")
    ("rail-enter-right" . "flip-delay-left")
    ("rail-return-left" . "flip-delay-left")))

(define (rail->flip-label label)
  (match (assoc label rail->flip-label-table)
    [(cons _ target) target]
    [#f (raise-argument-error 'rail->flip-label "known Railroad rule label" label)]))

(define (rail->flip/named-successors successors)
  (for/list ([successor (in-list successors)])
    (match successor
      [(list label configuration)
       (list (rail->flip-label label) (rail->flip/config configuration))]
      [_ (raise-argument-error 'rail->flip/named-successors
                               "list of named native successors" successors)])))
