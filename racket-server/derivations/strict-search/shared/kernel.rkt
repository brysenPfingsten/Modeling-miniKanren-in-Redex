#lang racket

(require redex/reduction-semantics
         (prefix-in s: "core/s/language.rkt")
         (prefix-in e: "core/e/language.rkt")
         (prefix-in n: "core/n/language.rkt"))

(provide (struct-out Failure) (struct-out Success)
         owners-support owners-append fresh-names substitute-goal
         define-atomic atomic/s atomic/e atomic/n allocate/s allocate/e allocate/n
         address-term address-goal address-state
         valid-support? named-variable? lexical-variable?)

;; State and kernel equations are the preserved selected representation
;; kernels. The host functions below expose only structural allocation,
;; lexical substitution, and atomic kernel operations to the strict source.
(define (named-variable? v)
  (and (symbol? v) (regexp-match? #rx"^u:" (symbol->string v))))

(define (lexical-variable? v)
  (and (symbol? v) (regexp-match? #rx"^x:" (symbol->string v))))

(define (valid-support? support)
  (and (list? support) (andmap named-variable? support)
       (= (length support) (length (remove-duplicates support)))))

(define (owners-support owners [prefix '()])
  (match owners
    [`(Owners) prefix]
    [`(Owners (Owner ,intro ,_) ,rest ...)
     (owners-support `(Owners ,@rest) (append prefix intro))]
    [_ (raise-argument-error 'owners-support "Owners" owners)]))

(define (owners-append outer inner)
  (match* (outer inner)
    [(`(Owners ,a ...) `(Owners ,b ...)) `(Owners ,@a ,@b)]))

;; Same least-unused allocation algorithm as the selected independent S
;; oracle. Incoming support order is retained; names are never sorted.
(define (fresh-names support count [candidate 0] [reversed '()])
  (cond
    [(zero? count) (reverse reversed)]
    [else
     (define name (string->symbol (format "u:~a" candidate)))
     (if (or (member name support) (member name reversed))
         (fresh-names support count (add1 candidate) reversed)
         (fresh-names support (sub1 count) (add1 candidate) (cons name reversed)))]))

(define (substitute-term value replacements)
  (match value
    [(? lexical-variable? x)
     (match (assoc x replacements) [(list _ v) v] [#f x])]
    [`(,a : ,d) `(,(substitute-term a replacements) : ,(substitute-term d replacements))]
    [_ value]))

(define (substitute-goal goal replacements)
  (match goal
    [`(,(and operator (or 'succeed 'fail)) ,tag) `(,operator ,tag)]
    [`(,left ,(and operator (or '=? '!=)) ,right ,tag)
     `(,(substitute-term left replacements) ,operator
       ,(substitute-term right replacements) ,tag)]
    [`(,left ,(and operator (or '∧ '∨)) ,right ,tag)
     `(,(substitute-goal left replacements) ,operator
       ,(substitute-goal right replacements) ,tag)]
    [`(∃ ,binders ,body ,tag)
     `(∃ ,binders ,(substitute-goal
                   body (filter (lambda (entry) (not (member (first entry) binders)))
                                replacements)) ,tag)]
    [`(suspend ,body ,tag) `(suspend ,(substitute-goal body replacements) ,tag)]
    [_ (raise-argument-error 'substitute-goal "first-order matrix goal" goal)]))

(define (allocate/s owners binders body tag state prefix)
  (define intro (fresh-names (owners-support owners prefix) (length binders)))
  `(eval ,(owners-append owners `(Owners (Owner ,intro ,tag)))
         ,(substitute-goal body (map list binders intro)) ,state))

(define (allocate/e binders body state)
  (match-define `(state (Support ,support ...) ,sub ,dis ,trail ,tag) state)
  (define intro (term (e:fresh-intro/e (Support ,@support) ,binders)))
  `(eval ,(substitute-goal body (map list binders intro))
         (state (Support ,@support ,@intro) ,sub ,dis ,trail ,tag)))

(define (allocate/n binders body state)
  (match-define `(state ,next ,sub ,dis ,trail ,tag) state)
  (define intro (term (n:allocate-interval/n ,next ,binders)))
  `(eval ,(substitute-goal body (map list binders intro))
         (state ,(+ next (length binders)) ,sub ,dis ,trail ,tag)))

;; Matrix outcomes are first-order results of completed atomic work. Native
;; source/Big equations inspect them as data, without callbacks or adapters.
(struct Failure () #:transparent)
(struct Success (state) #:transparent)

;; Specialize primitive equations over the native State carrier and result
;; producers at expansion time. The matrix rows below use data constructors.
;; The independent functional interpreter's test boundary can instantiate its
;; own producers directly; neither implementation runs or converts the other.
(define-syntax-rule (define-atomic name failure success walk unify invalid (sub dis trail tag)
                     state-pattern state-result)
  (define (name goal state)
    (match-define state-pattern state)
    (match goal
      [`(succeed ,_) (success state)]
      [`(fail ,_) (failure)]
      [`(,left =? ,right ,goal-tag)
       (define result (term (unify (walk ,left ,sub) (walk ,right ,sub) ,sub)))
       (if (and result (not (term (invalid ,result ,dis))))
           (success
            (let ([sub result] [trail (append trail (list goal))]) state-result))
           (failure))]
      [`(,left != ,right ,_)
       (define next-dis (cons (list left right) dis))
       (if (term (invalid ,sub ,next-dis))
           (failure)
           (success (let ([dis next-dis]) state-result)))]
      [_ (raise-argument-error 'name "atomic first-order goal" goal)])))

(define-atomic atomic/s Failure Success s:walk/s s:unify/s s:invalid?/s
  (sub dis trail tag)
  `(state ,sub ,dis ,trail ,tag) `(state ,sub ,dis ,trail ,tag))
(define-atomic atomic/e Failure Success e:walk/e e:unify/e e:invalid?/e
  (sub dis trail tag)
  `(state ,supply ,sub ,dis ,trail ,tag) `(state ,supply ,sub ,dis ,trail ,tag))
(define-atomic atomic/n Failure Success n:walk/n n:unify/n n:invalid?/n
  (sub dis trail tag)
  `(state ,supply ,sub ,dis ,trail ,tag) `(state ,supply ,sub ,dis ,trail ,tag))

(define (address-term value support)
  (match value
    [(? named-variable? name)
     (or (index-of support name)
         (error 'address-term "variable ~e is absent from support ~e" name support))]
    [`(,a : ,d) `(,(address-term a support) : ,(address-term d support))]
    [_ value]))

(define (address-goal goal support)
  (match goal
    [`(,(and operator (or 'succeed 'fail)) ,tag) `(,operator ,tag)]
    [`(,left ,(and operator (or '=? '!=)) ,right ,tag)
     `(,(address-term left support) ,operator ,(address-term right support) ,tag)]
    [`(,left ,(and operator (or '∧ '∨)) ,right ,tag)
     `(,(address-goal left support) ,operator ,(address-goal right support) ,tag)]
    [`(∃ ,binders ,body ,tag) `(∃ ,binders ,(address-goal body support) ,tag)]
    [`(suspend ,body ,tag) `(suspend ,(address-goal body support) ,tag)]
    [_ (raise-argument-error 'address-goal "matrix goal" goal)]))

(define (address-state state support)
  (unless (valid-support? support)
    (raise-argument-error 'address-state "ordered duplicate-free named support" support))
  (match-define `(state ,_ ,sub ,dis ,trail ,tag) state)
  `(state ,(length support)
          ,(for/list ([binding (in-list sub)])
             (match-define (list variable value) binding)
             (list (address-term variable support) (address-term value support)))
          ,(for/list ([constraint (in-list dis)])
             (map (lambda (v) (address-term v support)) constraint))
          ,(map (lambda (goal) (address-goal goal support)) trail)
          ,tag))
