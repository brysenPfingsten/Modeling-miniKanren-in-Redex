#lang racket

(require (only-in "../shared/kernel.rkt"
                  owners-support owners-append fresh-names substitute-goal)
         "../shared/kernel-equations.rkt")
(provide (all-defined-out))

;; P is inherited allocation support, O is local grouped provenance. Neither
;; is a field of logical State. Goal binding uses the S matrix's lexical syntax.
;; Evaluation produces active Search: Empty / One / Yield / Delay. Yield's
;; eager candidates may still pass through a pending bind. Only commit/s,
;; after the enclosing search has matured, constructs settled output.
(define (failure-outcome) (lambda (failure _success) (failure)))
(define (success-outcome state) (lambda (_failure success) (success state)))
(define-kernel atomic failure-outcome success-outcome)

(define (prefix owners search)
  (match search
    [`(Empty ,local) `(Empty ,(owners-append owners local))]
    [`(One ,local ,state) `(One ,(owners-append owners local) ,state)]
    [`(Yield ,local ,answer ,rest)
     `(Yield ,(owners-append owners local) ,answer ,rest)]
    [`(Delay ,local ,resume) `(Delay ,(owners-append owners local) ,resume)]))

(define (eval/s goal state owners inherited)
  (match goal
    [`(∃ ,binders ,body ,tag)
     (define intro (fresh-names (owners-support owners inherited) (length binders)))
     (eval/s (substitute-goal body (map list binders intro)) state
             (owners-append owners `(Owners (Owner ,intro ,tag))) inherited)]
    [`(,left ∧ ,right ,_)
     (bind/s (eval/s left state '(Owners) (owners-support owners inherited))
             (lambda (state* owners* inherited*)
               (eval/s right state* owners* inherited*))
             owners inherited)]
    [`(,left ∨ ,right ,_)
     (merge/s (eval/s left state '(Owners) (owners-support owners inherited))
              (eval/s right state '(Owners) (owners-support owners inherited))
              owners inherited)]
    [`(suspend ,body ,_)
     (define here (owners-support owners inherited))
     `(Delay ,owners ,(lambda () (eval/s body state '(Owners) here)))]
    [atom ((atomic atom state)
           (lambda () `(Empty ,owners))
           (lambda (next) `(One ,owners ,next)))]))

(define (merge/s left right owners inherited)
  (match left
    [`(Empty ,_) (prefix owners right)]
    [`(One ,local ,state) `(Yield ,owners (Answer ,local ,state) ,right)]
    [`(Yield ,local (Answer ,answer ,state) ,rest)
     `(Yield ,owners (Answer ,(owners-append local answer) ,state)
            ,(merge/s (prefix local rest) right '(Owners)
                      (owners-support owners inherited)))]
    [`(Delay ,_ ,_)
     (define here (owners-support owners inherited))
     `(Delay ,owners ,(lambda () (merge/s right (force/s left) '(Owners) here)))]))

(define (bind/s search continue owners inherited)
  (match search
    [`(Empty ,local) `(Empty ,(owners-append owners local))]
    [`(One ,local ,state)
     (continue state (owners-append owners local) inherited)]
    [`(Yield ,local (Answer ,answer ,state) ,rest)
     (define common (owners-append owners local))
     (define here (owners-support common inherited))
     (merge/s (continue state answer here)
              (bind/s rest continue '(Owners) here) common inherited)]
    [`(Delay ,local ,resume)
     (define common (owners-append owners local))
     (define here (owners-support common inherited))
     `(Delay ,common ,(lambda () (bind/s (resume) continue '(Owners) here)))]))

;; Internal forcing restores local ancestry on active Search. It never
;; commits a candidate and never records an exposed observation event.
(define (force/s search)
  (match search [`(Delay ,owners ,resume) (prefix owners (resume))]))

;; The commitment boundary: called only on the whole remaining search after
;; its eager evaluation/binds/merges finish. No search work runs here. At a
;; Delay, keep the active search explicitly under unfinished-work More.
(define (commit/s search)
  (match search
    [`(Empty ,owners) `(Done ,owners)]
    [`(One ,owners ,state) `(Last (Owners) (Answer ,owners ,state))]
    [`(Yield ,owners ,answer ,rest)
     `(Emit ,owners ,answer ,(commit/s rest))]
    [`(Delay ,_ ,_) `(More ,search)]))

;; Cross at most one EXPOSED Delay, keeping the completed prefix and previous
;; Forced evidence. Its body may do required internal scheduler forcing.
(define (resume-once frontier)
  (match frontier
    [`(Done ,_) frontier]
    [`(Last (Owners) ,_) frontier]
    [`(Emit ,owners ,answer ,rest) `(Emit ,owners ,answer ,(resume-once rest))]
    [`(Forced ,owners ,rest) `(Forced ,owners ,(resume-once rest))]
    [`(More (Delay ,owners ,resume)) `(Forced ,owners ,(commit/s (resume)))]))

;; An explicit finite consumer, never the basic interpreter interface.
(define (collect-all frontier)
  (match frontier
    [`(Done ,_) frontier]
    [`(Last (Owners) ,_) frontier]
    [`(Emit ,owners ,answer ,rest) `(Emit ,owners ,answer ,(collect-all rest))]
    [`(Forced ,owners ,rest) `(Forced ,owners ,(collect-all rest))]
    [`(More (Delay ,owners ,resume))
     `(Forced ,owners ,(collect-all (commit/s (resume))))]))

(define (run goal #:owners [owners '(Owners)]
             #:state [state '(state () () () (label "initial"))])
  (commit/s (eval/s goal state owners '())))
