#lang racket

(require rackunit
         rackunit/text-ui
         redex/reduction-semantics
         (prefix-in redex-parameter: redex/parameter)
         (prefix-in cross-module:
                    "stage-generators-parameter-derived-fixture.rkt")
         "stage-generators.rkt")

(provide STAGE-GENERATOR-SMOKE)

;; Deliberately foreign to miniKanren.  The constructors exercise every D
;; control reification case while making accidental core-specific cases in the
;; framework immediately visible.
(define-language foreign-base
  [E natural]
  [Result (Value E)]
  [Task (Pulse E)
     (Crash E)
     (Echo E)
     (Allocate E)
     (Value E)
     (Crashed E)]
  [World (Top Task)
     (Halted E)
     (Shell World)]
  [TaskPath hole]
  [TaskFocus (Shell (Top TaskPath))]
  [WorldSpine (Shell hole)])

;; Two deliberately distinct proofs of the same observable conclusion.  The
;; generated stages must preserve both derivations instead of normalizing the
;; result to a set.
(redex-parameter:define-judgment-form* foreign-base
  #:mode (foreign-echo-evidence I O)
  #:contract (foreign-echo-evidence E E)
  [---------------- "echo-left"
   (foreign-echo-evidence natural natural)]
  [---------------- "echo-right"
   (foreign-echo-evidence natural natural)])

(define-extended-language foreign-source
  foreign-base
  [E .... string]
  [Task ....
     (Box Task)]
  [TaskPath ....
            (Box TaskPath)])

;; This is a real Redex dependency extension, not a host-language parameter.
;; The inherited echo rule must select these two string cases when every
;; generated rule-bearing judgment is lifted to its own larger language.
(redex-parameter:define-extended-judgment-form*
 foreign-echo-evidence
 foreign-source
 #:mode (foreign-echo-evidence/extended I O)
 [---------------- "echo-string-left"
  (foreign-echo-evidence/extended string 7)]
 [---------------- "echo-string-right"
  (foreign-echo-evidence/extended string 7)])

(define-derivation-instance foreign/base
  #:source-language foreign-base
  #:redex-parameters ([echo-evidence foreign-echo-evidence])
  #:work Task
  #:frontier World
  #:settled Result
  #:work-focus TaskFocus
  #:spine-context WorldSpine
  #:environment E
  #:run-productions ((Pulse E)
                     (Crash E)
                     (Echo E)
                     (Allocate E))
  #:nonallocation-run-productions ((Pulse E)
                                    (Crash E)
                                    (Echo E))
  #:dead-view [E (Crashed E)]
  #:root-focus (Top hole)
  #:root-spine (Shell hole)
  #:frames ()
  #:work-redexes ((Pulse E)
                  (Crash E)
                  (Echo E))
  #:frontier-redexes ((Top (Value E))
                      (Top (Crashed E)))
  #:allocation-redexes ((Allocate E))
  #:terminals ((Shell (Halted E)))
  #:open-work-productions ()
  #:rules
  ([pulse
    #:site work
    #:from (run (Pulse E_0) TaskFocus)
    #:to (settled (Value E_1) TaskFocus)
    #:premises ((where E_1 ,(add1 (term E_0))))]
   [crash
    #:site work
    #:from (run (Crash E) TaskFocus)
    #:to (dead E (Crashed E) TaskFocus)
    #:premises ()]
   [echo
    #:site work
    #:from (run (Echo E_0) TaskFocus)
    #:to (run (Pulse E_1) TaskFocus)
    #:premises ((echo-evidence E_0 E_1))]
   [allocate
    #:site allocation
    #:from (run (Allocate E) TaskFocus)
    #:to (run (Pulse E) TaskFocus)
    #:premises ()]
   [finish-value
    #:site frontier
    #:from (root-settled (Value E) WorldSpine)
    #:to (final (Halted E) WorldSpine)
    #:premises ()]
   [finish-crash
    #:site frontier
    #:from (root-dead E (Crashed E) WorldSpine)
    #:to (final (Halted E) WorldSpine)
    #:premises ()]))

;; The augmentation declares its new syntax, dependency override, frame
;; algebra, and two rules.  Later stages consume the premerged instance without
;; knowing Box or the concrete evidence judgment.  This fixture demonstrates
;; propagation from one declaration, not separate staging and recombination.
(define-derivation-delta foreign/I
  #:from foreign/base
  #:source-language foreign-source
  #:redex-parameter-overrides
  ([echo-evidence foreign-echo-evidence/extended])
  #:run-productions-add ()
  #:nonallocation-run-productions-add ()
  #:frames-add ((Box hole))
  #:work-redexes-add ((Box (Value E))
                      (Box (Crashed E)))
  #:frontier-redexes-add ()
  #:allocation-redexes-add ()
  #:terminals-add ()
  #:open-work-productions-add ((Box OpenW))
  #:rules-add
  ([pop-value
    #:site work
    #:from (pop-settled (Box hole) (Value E) TaskFocus)
    #:to (settled (Value E) TaskFocus)
    #:premises ()]
   [pop-crash
    #:site work
    #:from (pop-dead (Box hole) E (Crashed E) TaskFocus)
    #:to (dead E (Crashed E) TaskFocus)
    #:premises ()]))

(define-decomposition-stage foreign/D
  #:from foreign/I
  #:language foreign-D-lang
  #:plug-D foreign-plug-D
  #:plug-C foreign-plug-C
  #:contract-label foreign-contract-label
  #:decompose foreign-decompose
  #:contract foreign-contract
  #:step foreign-D-step)

(define-refocused-stage foreign/Z
  #:from foreign/D
  #:language foreign-Z-lang
  #:D->Z foreign-D->Z
  #:Z->D foreign-Z->D
  #:readback foreign-readback-Z
  #:refocus-spec foreign-refocus/spec
  #:refocus-work-direct foreign-refocus-work/direct
  #:refocus-direct foreign-refocus/direct
  #:step-spec foreign-Z-step/spec
  #:step-direct foreign-Z-step/direct)

(define-machine-isomorphism-stage foreign/M
  #:from foreign/Z
  #:language foreign-M-lang
  #:encode-ZM foreign-encode-ZM
  #:decode-MZ foreign-decode-MZ
  #:D->M foreign-D->M
  #:M->D foreign-M->D
  #:readback foreign-readback-M
  #:refocus-work-direct foreign-machine-refocus-work/direct
  #:refocus-direct foreign-machine-refocus/direct
  #:step-direct foreign-M-step/direct
  #:corresponds foreign-ZM-corresponds
  #:step-spec foreign-M-step/spec
  #:square foreign-ZM-square)

(define-compression-policy foreign/compression
  #:settled-producers (pulse)
  #:dead-producers (crash)
  #:settled-followers (pop-value finish-value)
  #:dead-followers (pop-crash finish-crash)
  #:singletons (echo allocate pop-value pop-crash finish-value finish-crash)
  #:retained-observation rule-labels
  #:maximum-span 2)

(define-compressed-stage foreign/B
  #:from foreign/M
  #:policy foreign/compression
  #:language foreign-B-lang
  #:encode-MB foreign-encode-MB
  #:decode-BM foreign-decode-BM
  #:readback foreign-readback-B
  #:span-labels foreign-span-labels
  #:produce-settled foreign-produce-settled
  #:produce-dead foreign-produce-dead
  #:advance-settled foreign-advance-settled
  #:advance-dead foreign-advance-dead
  #:step-direct foreign-B-step/direct
  #:corresponds foreign-MB-corresponds
  #:replay foreign-replay/M
  #:step-spec foreign-B-step/spec
  #:square foreign-MB-square)

(define-fixed-point-stage foreign/Big
  #:from foreign/B
  #:language foreign-Big-lang
  #:readback foreign-readback-Big
  #:dispatch foreign-big-dispatch/direct
  #:run foreign-big-run/direct
  #:settled foreign-big-settled/direct
  #:dead foreign-big-dead/direct
  #:final foreign-big-final/direct
  #:evaluate foreign-big-evaluate/direct
  #:spec-language foreign-Big-spec-lang
  #:initialize foreign-initialize-B/spec
  #:close foreign-close-B/spec
  #:flatten foreign-flatten-BTrace
  #:promote foreign-promote-B/direct
  #:evaluate-spec foreign-big-evaluate/spec
  #:unfold-square foreign-B-Big-unfold-square
  #:closure-square foreign-B-Big-closure-square
  #:root-square foreign-B-Big-root-square)

(define/provide-test-suite STAGE-GENERATOR-SMOKE
  (test-case
   "the four grammatical partitions retain one raw proof each"
   (for ([frontier
          (in-list
           (list (term (Shell (Top (Pulse 2))))
                 (term (Shell (Top (Box (Value 2)))))
                 (term (Shell (Top (Allocate 2))))
                 (term (Shell (Halted 2)))))])
     (check-equal?
      (length
       (build-derivations
        (foreign-decompose ,frontier D)))
      1)))

  (test-case
   "ordered where premises and labels are rendered into D"
   (define source-D
     (term (DecWork (Pulse 2) (Shell (Top hole)))))
   (check-equal?
    (length
     (build-derivations
      (foreign-contract ,source-D C)))
    1)
   (check-equal?
    (judgment-holds
     (foreign-contract ,source-D C)
     C)
    (term
     ((ContractWork pulse (Value 3) (Shell (Top hole))))))
   (check-equal?
    (term
     (foreign-contract-label
      (ContractWork pulse (Value 3) (Shell (Top hole)))))
    'pulse))

  (test-case
   "allocation, frame-pop, dead, root, and final controls reify"
   (define cases
     (list
      (list
       (term (DecAllocate (Allocate 4) (Shell (Top hole))))
       (term (ContractWork allocate (Pulse 4) (Shell (Top hole)))))
      (list
       (term (DecWork (Box (Value 5)) (Shell (Top hole))))
       (term (ContractWork pop-value (Value 5) (Shell (Top hole)))))
      (list
       (term (DecWork (Box (Crashed 6)) (Shell (Top hole))))
       (term (ContractWork pop-crash (Crashed 6) (Shell (Top hole)))))
      (list
       (term (DecFrontier (Top (Value 7)) (Shell hole)))
       (term (ContractFrontier finish-value (Halted 7) (Shell hole))))
      (list
       (term (DecFrontier (Top (Crashed 8)) (Shell hole)))
       (term (ContractFrontier finish-crash (Halted 8) (Shell hole))))))
   (for ([one-case (in-list cases)])
     (match-define (list source-D expected-C) one-case)
     (check-equal?
      (judgment-holds
       (foreign-contract ,source-D C)
       C)
      (list expected-C))
     (check-equal?
      (length
       (build-derivations
        (foreign-contract ,source-D C)))
      1)))

  (test-case
   "the generated decomposed step preserves raw uniqueness"
   (define source-D
     (term (DecWork (Pulse 9) (Shell (Top hole)))))
   (check-equal?
    (judgment-holds
     (foreign-D-step ,source-D RuleName D_next)
     (RuleName D_next))
    (term
     ((pulse
       (DecFrontier (Top (Value 10)) (Shell hole))))))
   (check-equal?
    (length
     (build-derivations
      (foreign-D-step ,source-D RuleName D_next)))
    1))

  (test-case
   "a lifted Redex dependency preserves raw proofs through D, B, and Big"
   (define source-D
     (term (DecWork (Echo "lifted") (Shell (Top hole)))))
   (define source-B
     (term (BRun (Echo "lifted") (Shell (Top hole)))))
   (define source-World
     (term (Shell (Top (Echo "lifted")))))
   (define expected-contractum
     (term (ContractWork echo (Pulse 7) (Shell (Top hole)))))
   (define expected-D
     (term (DecWork (Pulse 7) (Shell (Top hole)))))
   (define expected-B
     (term (BRun (Pulse 7) (Shell (Top hole)))))
   (define expected-Big
     (term (BigFinal (Shell (Halted 8)))))
   (define expected-trace
     (term ((transition-span echo)
            (transition-span pulse finish-value))))
   (check-equal?
    (judgment-holds
     (foreign-echo-evidence/extended "lifted" E)
     E)
    (term (7)))
   (check-equal?
    (length
     (build-derivations
      (foreign-echo-evidence/extended "lifted" E)))
    2)
   (check-equal?
    (judgment-holds
     (foreign-contract ,source-D C)
     C)
    (list expected-contractum))
   (check-equal?
    (length
     (build-derivations
      (foreign-contract ,source-D C)))
    2)
   (check-equal?
    (judgment-holds
     (foreign-D-step ,source-D RuleName D_next)
     (RuleName D_next))
    (list (list 'echo expected-D)))
   (check-equal?
    (length
     (build-derivations
      (foreign-D-step ,source-D RuleName D_next)))
    2)
   (check-equal?
    (judgment-holds
     (foreign-B-step/direct ,source-B TransitionSpan B_next)
     (TransitionSpan B_next))
    (list (list (term (transition-span echo)) expected-B)))
   (check-equal?
    (judgment-holds
     (foreign-B-step/spec ,source-B TransitionSpan B_next)
     (TransitionSpan B_next))
    (list (list (term (transition-span echo)) expected-B)))
   (check-equal?
    (length
     (build-derivations
      (foreign-B-step/direct ,source-B TransitionSpan B_next)))
    2)
   (check-equal?
    (length
     (build-derivations
      (foreign-B-step/spec ,source-B TransitionSpan B_next)))
    2)
   (check-equal?
    (judgment-holds
     (foreign-big-evaluate/direct ,source-World Big)
     Big)
    (list expected-Big))
   (check-equal?
    (judgment-holds
     (foreign-big-evaluate/spec ,source-World BTrace Big)
     (BTrace Big))
    (list (list expected-trace expected-Big)))
   (check-equal?
    (length
     (build-derivations
      (foreign-big-evaluate/direct ,source-World Big)))
    2)
   (check-equal?
    (length
     (build-derivations
      (foreign-big-evaluate/spec ,source-World BTrace Big)))
    2))

  (test-case
   "a delta-added rule resolves an inherited Redex slot across modules"
   (define source-D
     (term (DecWork (Query "cross-module") (Root hole))))
   (define rejected-D
     (term (DecWork (Query "wrong-host-value") (Root hole))))
   (define source-B
     (term (BRun (Query "cross-module") (Root hole))))
   (define source-Frontier
     (term (Root (Query "cross-module"))))
   (define expected-contractum
     (term (ContractWork query (Tick 7) (Root hole))))
   (define expected-D
     (term (DecWork (Tick 7) (Root hole))))
   (define expected-B
     (term (BRun (Tick 7) (Root hole))))
   (define expected-Big
     (term (BigFinal (Halted 8))))
   (define expected-trace
     (term ((transition-span query)
            (transition-span tick finish))))
   (check-equal?
    (judgment-holds
     (cross-module:hygiene-evidence/extended "cross-module" N)
     N)
    (term (7)))
   (check-equal?
    (length
     (build-derivations
      (cross-module:hygiene-evidence/extended "cross-module" N)))
    2)
   (check-equal?
    (judgment-holds
     (cross-module:hygiene-contract ,source-D C)
     C)
    (list expected-contractum))
   (check-equal?
    (length
     (build-derivations
      (cross-module:hygiene-contract ,source-D C)))
    2)
   (check-equal?
    (length
     (build-derivations
      (cross-module:hygiene-contract ,rejected-D C)))
    0)
   (check-equal?
    (judgment-holds
     (cross-module:hygiene-D-step ,source-D RuleName D_next)
     (RuleName D_next))
    (list (list 'query expected-D)))
   (check-equal?
    (length
     (build-derivations
      (cross-module:hygiene-D-step ,source-D RuleName D_next)))
    2)
   (check-equal?
    (judgment-holds
     (cross-module:hygiene-B-step/direct
      ,source-B TransitionSpan B_next)
     (TransitionSpan B_next))
    (list (list (term (transition-span query)) expected-B)))
   (check-equal?
    (judgment-holds
     (cross-module:hygiene-B-step/spec
      ,source-B TransitionSpan B_next)
     (TransitionSpan B_next))
    (list (list (term (transition-span query)) expected-B)))
   (check-equal?
    (length
     (build-derivations
      (cross-module:hygiene-B-step/direct
       ,source-B TransitionSpan B_next)))
    2)
   (check-equal?
    (length
     (build-derivations
      (cross-module:hygiene-B-step/spec
       ,source-B TransitionSpan B_next)))
    2)
   (check-equal?
    (judgment-holds
     (cross-module:hygiene-big-evaluate/direct ,source-Frontier Big)
     Big)
    (list expected-Big))
   (check-equal?
    (judgment-holds
     (cross-module:hygiene-big-evaluate/spec
      ,source-Frontier BTrace Big)
     (BTrace Big))
    (list (list expected-trace expected-Big)))
   (check-equal?
    (length
     (build-derivations
      (cross-module:hygiene-big-evaluate/direct ,source-Frontier Big)))
    2)
   (check-equal?
    (length
     (build-derivations
      (cross-module:hygiene-big-evaluate/spec
       ,source-Frontier BTrace Big)))
    2))

  (test-case
   "direct refocusing agrees with plug/decompose at frames and the root"
   (define contracta
     (list
      (term
       (ContractWork pulse (Value 3)
                     (Shell (Top (Box hole)))))
      (term
       (ContractWork allocate (Box (Pulse 4))
                     (Shell (Top hole))))
      (term
       (ContractWork pop-crash (Crashed 5)
                     (Shell (Top hole))))))
   (for ([contractum (in-list contracta)])
     (define direct
       (judgment-holds
        (foreign-refocus/direct ,contractum Z)
        Z))
     (define spec
       (judgment-holds
        (foreign-refocus/spec ,contractum Z)
        Z))
     (check-equal? direct spec)
     (check-equal?
      (length
       (build-derivations
        (foreign-refocus/direct ,contractum Z)))
      1)
     (check-equal?
      (length
       (build-derivations
        (foreign-refocus/spec ,contractum Z)))
      1)))

  (test-case
   "the four D/Z codec cases preserve readback"
   (define decompositions
     (list
      (term (Final (Shell (Halted 1))))
      (term (DecWork (Pulse 2) (Shell (Top hole))))
      (term (DecFrontier (Top (Value 3)) (Shell hole)))
      (term (DecAllocate (Allocate 4) (Shell (Top hole))))))
   (for ([decomposition (in-list decompositions)])
     (define refocused (term (foreign-D->Z ,decomposition)))
     (check-true (redex-match? foreign-Z-lang Z refocused))
     (check-equal?
      (term (foreign-Z->D ,refocused))
      decomposition)
     (check-equal?
      (term (foreign-readback-Z ,refocused))
      (term (foreign-plug-D ,decomposition)))))

  (test-case
   "direct and specified Z edges retain exact labels and proofs"
   (define source-Z
     (term (ZWork (Pulse 9) (Shell (Top hole)))))
   (define expected
     (term
      (pulse
       (ZFrontier (Top (Value 10)) (Shell hole)))))
   (check-equal?
    (judgment-holds
     (foreign-Z-step/direct ,source-Z RuleName Z_next)
     (RuleName Z_next))
    (list expected))
   (check-equal?
    (judgment-holds
     (foreign-Z-step/spec ,source-Z RuleName Z_next)
     (RuleName Z_next))
    (list expected))
   (check-equal?
    (length
     (build-derivations
      (foreign-Z-step/direct ,source-Z RuleName Z_next)))
    1)
   (check-equal?
    (length
     (build-derivations
      (foreign-Z-step/spec ,source-Z RuleName Z_next)))
    1))

  (test-case
   "Z and M are a four-way structural isomorphism"
   (define refocused-cases
     (list
      (term (ZFinal (Shell (Halted 1))))
      (term (ZWork (Pulse 2) (Shell (Top hole))))
      (term (ZFrontier (Top (Value 3)) (Shell hole)))
      (term (ZAllocate (Allocate 4) (Shell (Top hole))))))
   (for ([refocused (in-list refocused-cases)])
     (define machine (term (foreign-encode-ZM ,refocused)))
     (check-true (redex-match? foreign-M-lang M machine))
     (check-equal?
      (term (foreign-decode-MZ ,machine))
      refocused)
     (check-equal?
      (term (foreign-readback-M ,machine))
      (term (foreign-readback-Z ,refocused)))))

  (test-case
   "mechanically specialized M edges commute with transported Z"
   (define source-Z
     (term (ZWork (Pulse 11) (Shell (Top hole)))))
   (define source-M
     (term (foreign-encode-ZM ,source-Z)))
   (define expected
     (term
      (pulse
       (MFrontier (Top (Value 12)) (Shell hole)))))
   (check-equal?
    (judgment-holds
     (foreign-M-step/direct ,source-M RuleName M_next)
     (RuleName M_next))
    (list expected))
   (check-equal?
    (judgment-holds
     (foreign-M-step/spec ,source-M RuleName M_next)
     (RuleName M_next))
    (list expected))
   (check-equal?
    (length
     (build-derivations
      (foreign-M-step/direct ,source-M RuleName M_next)))
    1)
   (check-equal?
    (length
     (build-derivations
      (foreign-M-step/spec ,source-M RuleName M_next)))
    1)
   (check-equal?
    (length
     (build-derivations
      (foreign-ZM-square
       ,source-Z RuleName Z_next M_0 M_1)))
    1))

  (test-case
   "canonical M/B codecs cover all four controls and preserve readback"
   (define machines
     (list
      (term (MFinal (Shell (Halted 1))))
      (term (MWork (Pulse 2) (Shell (Top hole))))
      (term (MAllocate (Allocate 3) (Shell (Top hole))))
      (term (MWork (Box (Value 4)) (Shell (Top hole))))
      (term (MWork (Box (Crashed 5)) (Shell (Top hole))))
      (term (MFrontier (Top (Value 6)) (Shell hole)))
      (term (MFrontier (Top (Crashed 7)) (Shell hole)))))
   (for ([machine (in-list machines)])
     (define compressed (term (foreign-encode-MB ,machine)))
     (check-true (redex-match? foreign-B-lang B compressed))
     (check-equal? (term (foreign-decode-BM ,compressed)) machine)
     (check-equal? (term (foreign-readback-B ,compressed))
                   (term (foreign-readback-M ,machine)))))

  (test-case
   "direct B emits exact one/two-label spans and matches M replay"
   (check-false
    (redex-match?
     foreign-B-lang
     TransitionSpan
     (term (transition-span pulse pop-value finish-value))))
   (define cases
     (list
      (list
       (term (BRun (Pulse 1) (Shell (Top (Box hole)))))
       (term (transition-span pulse pop-value))
       (term (BSettled (Value 2) (Shell (Top hole)))))
      (list
       (term (BRun (Crash 3) (Shell (Top (Box hole)))))
       (term (transition-span crash pop-crash))
       (term (BDead 3 (Shell (Top hole)))))
      (list
       (term (BRun (Allocate 4) (Shell (Top hole))))
       (term (transition-span allocate))
       (term (BRun (Pulse 4) (Shell (Top hole)))))
      (list
       (term (BSettled (Value 5) (Shell (Top hole))))
       (term (transition-span finish-value))
       (term (BFinal (Shell (Halted 5)))))
      (list
       (term (BDead 6 (Shell (Top hole))))
       (term (transition-span finish-crash))
       (term (BFinal (Shell (Halted 6)))))))
   (for ([one-case (in-list cases)])
     (match-define (list source span target) one-case)
     (define direct
       (judgment-holds
        (foreign-B-step/direct ,source TransitionSpan B_next)
        (TransitionSpan B_next)))
     (define spec
       (judgment-holds
        (foreign-B-step/spec ,source TransitionSpan B_next)
        (TransitionSpan B_next)))
     (check-equal? direct (list (list span target)))
     (check-equal? direct spec)
     (check-equal?
      (length
       (build-derivations
        (foreign-B-step/direct ,source TransitionSpan B_next)))
      1)
     (check-equal?
      (length
       (build-derivations
        (foreign-B-step/spec ,source TransitionSpan B_next)))
      1)
     (check-equal?
      (length
       (build-derivations
        (foreign-MB-square
         ,source TransitionSpan B_next M_0 M_1)))
      1)))

  (test-case
   "Big is a direct fixed point with an independently traced B closure"
   (define source (term (Shell (Top (Box (Pulse 1))))))
   (define expected (term (BigFinal (Shell (Halted 2)))))
   (define expected-trace
     (term ((transition-span pulse pop-value)
            (transition-span finish-value))))
   (check-equal?
    (judgment-holds
     (foreign-big-evaluate/direct ,source Big)
     Big)
    (list expected))
   (check-equal?
    (judgment-holds
     (foreign-big-evaluate/spec ,source BTrace Big)
     (BTrace Big))
    (list (list expected-trace expected)))
   (check-equal?
    (judgment-holds
     (foreign-B-Big-root-square ,source BTrace Big)
     (BTrace Big))
    (list (list expected-trace expected)))
   (check-equal?
    (term (foreign-flatten-BTrace ,expected-trace))
    (term (pulse pop-value finish-value)))
   (check-equal?
    (length
     (build-derivations
      (foreign-big-evaluate/direct ,source Big)))
    1)
   (check-equal?
    (length
     (build-derivations
      (foreign-big-evaluate/spec ,source BTrace Big)))
    1)
   (check-equal?
    (length
     (build-derivations
      (foreign-B-Big-root-square ,source BTrace Big)))
    1))

  (test-case
   "ambiguous policies, invalid parameters, and duplicate deltas fail"
   (check-exn
    exn:fail:syntax?
    (lambda ()
      (expand
       #'(let ()
         (define-compression-policy foreign/duplicate-policy
           #:settled-producers (pulse pulse)
           #:dead-producers (crash)
           #:settled-followers (pop-value finish-value)
           #:dead-followers (pop-crash finish-crash)
           #:singletons
           (echo allocate pop-value pop-crash finish-value finish-crash)
           #:retained-observation rule-labels
           #:maximum-span 2)
         #t))))
   (check-exn
    #rx"Redex parameter local identifiers must be distinct"
    (lambda ()
      (expand
       #'(let ()
         (define-derivation-instance foreign/duplicate-parameter-local
           #:source-language foreign-base
           #:redex-parameters
           ([echo-evidence foreign-echo-evidence]
            [echo-evidence foreign-echo-evidence/extended])
           #:work Task
           #:frontier World
           #:settled Result
           #:work-focus TaskFocus
           #:spine-context WorldSpine
           #:environment E
           #:run-productions ()
           #:nonallocation-run-productions ()
           #:dead-view [E (Crashed E)]
           #:root-focus (Top hole)
           #:root-spine (Shell hole)
           #:frames ()
           #:work-redexes ()
           #:frontier-redexes ()
           #:allocation-redexes ()
           #:terminals ()
           #:open-work-productions ()
           #:rules ())
         #t))))
   (check-exn
    #rx"redex-parameters-add must introduce a fresh local identifier"
    (lambda ()
      (expand
       #'(let ()
         (define-derivation-delta foreign/colliding-parameter-add
           #:from foreign/base
           #:source-language foreign-source
           #:redex-parameters-add
           ([echo-evidence foreign-echo-evidence/extended])
           #:run-productions-add ()
           #:nonallocation-run-productions-add ()
           #:frames-add ()
           #:work-redexes-add ()
           #:frontier-redexes-add ()
           #:allocation-redexes-add ()
           #:terminals-add ()
           #:open-work-productions-add ()
           #:rules-add ())
         #t))))
   (check-exn
    #rx"redex-parameter-overrides must name an inherited local identifier"
    (lambda ()
      (expand
       #'(let ()
         (define-derivation-delta foreign/unknown-parameter-override
           #:from foreign/base
           #:source-language foreign-source
           #:redex-parameter-overrides
           ([unknown-evidence foreign-echo-evidence/extended])
           #:run-productions-add ()
           #:nonallocation-run-productions-add ()
           #:frames-add ()
           #:work-redexes-add ()
           #:frontier-redexes-add ()
           #:allocation-redexes-add ()
           #:terminals-add ()
           #:open-work-productions-add ()
           #:rules-add ())
         #t))))
   (check-exn
    exn:fail:syntax?
    (lambda ()
      (expand
       #'(let ()
         (define-compression-policy foreign/overlap-policy
           #:settled-producers (pulse)
           #:dead-producers (crash)
           #:settled-followers (pop-value finish-value)
           #:dead-followers (pop-crash finish-crash)
           #:singletons
           (pulse echo allocate pop-value pop-crash finish-value finish-crash)
           #:retained-observation rule-labels
           #:maximum-span 2)
         #t))))
   (check-exn
    exn:fail:syntax?
    (lambda ()
      (expand
       #'(let ()
         (define-compression-policy foreign/unsupported-observation
           #:settled-producers (pulse)
           #:dead-producers (crash)
           #:settled-followers (pop-value finish-value)
           #:dead-followers (pop-crash finish-crash)
           #:singletons
           (echo allocate pop-value pop-crash finish-value finish-crash)
           #:retained-observation final-result-only
           #:maximum-span 2)
         #t))))
   (check-exn
    exn:fail:syntax?
    (lambda ()
      (expand
       #'(let ()
         (define-derivation-delta foreign/duplicate-frame
           #:from foreign/I
           #:source-language foreign-source
           #:run-productions-add ()
           #:nonallocation-run-productions-add ()
           #:frames-add ((Box hole))
           #:work-redexes-add ()
           #:frontier-redexes-add ()
           #:allocation-redexes-add ()
           #:terminals-add ()
           #:open-work-productions-add ()
           #:rules-add ())
         #t))))))

(module+ test
  (run-tests STAGE-GENERATOR-SMOKE))
