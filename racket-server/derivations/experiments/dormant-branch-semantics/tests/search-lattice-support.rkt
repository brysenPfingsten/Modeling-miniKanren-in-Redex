#lang racket

(require redex/reduction-semantics)

(provide final-program?
         produced-answer-spine-only?
         tagged-successor-name
         tagged-successor-cfg
         sigma-a
         sigma-b
         sigma-s
         gamma-delay
         cfg-disj
         cfg-delay-goal
         delayed-left-search
         scoped-delayed-left-search
         cfg-scoped-delay-through-conj
         cfg-flip
         cfg-scoped-flip
         cfg-rail
         cfg-scoped-rail
         cfg-mixed-answer
         cfg-mixed-fail
         cfg-call
         cfg-call-branch
         cfg-call-rail)

(define (final-frontier? f)
  (match f
    [(list 'Done (list 'Owners (list 'Owner _ _) ...)) #t]
    [(list 'Last (list 'Owners (list 'Owner _ _) ...) _) #t]
    [(list 'Forced (list 'Owners (list 'Owner _ _) ...) inner)
     (final-frontier? inner)]
    [(list 'Emit (list 'Owners (list 'Owner _ _) ...) _ rest)
     (final-frontier? rest)]
    [_ #f]))

(define (final-program? prog)
  (match prog
    [`(,(? list?) ,f)
     (final-frontier? f)]
    [f
     (final-frontier? f)]))

(define (produced-answer-spine-only? prog
                                    [inside-branch? #f])
  (match prog
    [`(,(? list?) ,frontier)
     (produced-answer-spine-only? frontier inside-branch?)]
    [`(More ,work)
     (produced-answer-spine-only? work inside-branch?)]
    [`(Last (Owners ,_owner ...) ,answer)
     (produced-answer-spine-only? answer inside-branch?)]
    [`(Forced (Owners ,_owner ...) ,inner)
     (produced-answer-spine-only? inner inside-branch?)]
    [`(PendingDelay (Owners ,_owner ...) ,inner)
     (produced-answer-spine-only? inner inside-branch?)]
    [`(Conj (Owners ,_owner ...) ,work ,_g)
     (produced-answer-spine-only? work inside-branch?)]
    [`(Emit (Owners ,_owner ...) ,answer ,rest)
     (and (not inside-branch?)
          (produced-answer-spine-only? answer inside-branch?)
          (produced-answer-spine-only? rest inside-branch?))]
    [`(DisjL (Owners ,_owner ...) ,left ,right)
     (and (produced-answer-spine-only? left #t)
          (produced-answer-spine-only? right #t))]
    [`(DisjR (Owners ,_owner ...) ,left ,right)
     (and (produced-answer-spine-only? left #t)
          (produced-answer-spine-only? right #t))]
    [_ #t]))

(define (tagged-successor-name succ)
  (match succ
    [(list name _cfg) (~a name)]
    [_ "<unknown>"]))

(define (tagged-successor-cfg succ)
  (match succ
    [(list _name cfg) cfg]
    [_ succ]))

(define sigma-a
  (term (state () () () (label "a"))))

(define sigma-b
  (term (state () () () (label "b"))))

(define sigma-s
  (term (state () () () (label "s"))))

(define gamma-delay
  (term ((r:delay ()
                  (suspend (succeed (label "inner"))
                           (label "zz"))))))

(define cfg-disj
  (term (More (DisjL (Owners)
                     (Returned (Owners) ,sigma-a)
                     (Returned (Owners) ,sigma-b)))))

(define cfg-delay-goal
  (term (More
         (Work (Owners)
               (suspend (succeed (label "inner")) (label "delay"))
               ,sigma-s))))

(define delayed-left-search
  (term (PendingDelay (Owners)
                      (Work (Owners) (succeed (label "late")) ,sigma-s))))

(define scoped-delayed-left-search
  (term (PendingDelay (Owners (Owner (u:0) (label "fresh")))
                      (Work (Owners) (succeed (label "late")) ,sigma-s))))

(define cfg-scoped-delay-through-conj
  (term (More
         (Conj (Owners)
               ,scoped-delayed-left-search
               (succeed (label "k"))))))

(define cfg-flip
  (term (More
         (DisjL (Owners)
                ,delayed-left-search
                (Returned (Owners) ,sigma-b)))))

(define cfg-scoped-flip
  (term (More
         (DisjL (Owners)
                ,scoped-delayed-left-search
                (Returned (Owners) ,sigma-b)))))

(define cfg-rail
  (term (More
         (DisjL (Owners)
                ,delayed-left-search
                (Returned (Owners) ,sigma-b)))))

(define cfg-scoped-rail
  (term (More
         (DisjL (Owners)
                ,scoped-delayed-left-search
                (Returned (Owners) ,sigma-b)))))

(define cfg-mixed-answer
  (term (More
         (DisjL (Owners)
          (Conj (Owners)
                (DisjL (Owners)
                       (Returned (Owners) ,sigma-a)
                       (Returned (Owners) ,sigma-b))
                (succeed (label "k")))
          (Dead (Owners))))))

(define cfg-mixed-fail
  (term (More
         (DisjL (Owners)
          (Conj (Owners)
                (DisjL (Owners) (Dead (Owners)) (Returned (Owners) ,sigma-b))
                (succeed (label "k")))
          (Dead (Owners))))))

(define cfg-call
  (term (,gamma-delay
         (More
          (Work (Owners) (r:delay (label "call")) ,sigma-a)))))

(define cfg-call-branch
  (term (,gamma-delay
         (More
          (DisjL (Owners)
                 (Work (Owners) (r:delay (label "call")) ,sigma-a)
                 (Returned (Owners) ,sigma-b))))))

(define cfg-call-rail
  (term (,gamma-delay
         (More
          (DisjL (Owners)
                 (Work (Owners) (r:delay (label "call")) ,sigma-a)
                 (Returned (Owners) ,sigma-b))))))
