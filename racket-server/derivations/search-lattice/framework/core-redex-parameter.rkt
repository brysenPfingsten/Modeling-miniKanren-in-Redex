#lang racket/base

;; Selected-only transitive dependency lifting for the staged-row renderer.
;;
;; This module is derived from `redex/parameter` 0.3 by Cameron Moy
;; (<https://github.com/camoy/redex-parameter>, package source `parameter.rkt`).
;; Copyright (C) 2020 by Cameron Moy <mail@camoy.name>
;;
;; Permission to use, copy, modify, and/or distribute this software for any
;; purpose with or without fee is hereby granted.
;;
;; THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
;; WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
;; MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY
;; SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
;; WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN ACTION
;; OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF OR IN
;; CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
;;
;; The two selected-only deltas from upstream are documented at
;; `redex-obj-maker` and `redex-obj-add-ext!` below.  The remaining machinery
;; intentionally tracks the upstream implementation.

(provide define-reduction-relation
         define-extended-reduction-relation
         define-reduction-relation*
         define-extended-reduction-relation*
         define-extended-metafunction
         define-metafunction*
         define-extended-metafunction*
         define-judgment-form*
         define-extended-judgment-form*)

(require (for-syntax racket/base
                     racket/match
                     racket/provide-transform
                     racket/sequence
                     racket/syntax
                     redex/private/term-fn
                     syntax/id-table
                     syntax/parse
                     syntax/strip-context)
         racket/splicing
         redex/reduction-semantics)

(begin-for-syntax
  (define-splicing-syntax-class params
    (pattern (~seq #:parameters ([param:id val:id] ...)))
    (pattern (~seq)
             #:attr (param 1) null
             #:attr (val 1) null))

  (define-syntax-class mode
    (pattern (name:id _ ...))))

(begin-for-syntax
  ;; A Redex object is a rename transformer whose arguments can reconstruct it
  ;; in another language and whose extension table chooses an exact-language
  ;; implementation for a dependency.
  (struct redex-obj (id args exts) #:property prop:rename-transformer 0)

  (define ((redex-obj-maker who name base params vals defn) sc lang)
    ;; Upstream captures an extended object's already-lifted immediate base in
    ;; its stored definition.  That freezes Base@L1 inside Delta1 and prevents
    ;; reconstructing Delta1 at L2.  Resolve the original base recursively for
    ;; every requested language and bind it through the stored `*BASE*` slot.
    (define-values (base-id base-defn)
      (if (and (syntax? base) (syntax-e base))
          (match (lift base lang)
            [(list id definition) (values id definition)])
          (values (generate-temporary '*no-base*) #'(void))))
    (define param-stx (make-params params vals sc lang))
    (define defn* (sc defn))
    (with-syntax ([?lang (replace-context defn* #'*LANG*)]
                  [?base-placeholder (replace-context defn* #'*BASE*)]
                  [?base-id base-id]
                  [?base-lift base-defn]
                  [([?param ?val ?lift] ...) param-stx])
      (values (sc name)
              #`(begin
                  ?base-lift
                  ?lift ...
                  (splicing-let-syntax
                      ([?lang (make-rename-transformer #'#,lang)]
                       [?base-placeholder
                        (make-rename-transformer #'?base-id)]
                       [?param (make-rename-transformer #'?val)]
                       ...)
                    #,defn*)))))

  (define (redex-obj-syntax who name base lang params vals defn)
    (define sc (make-syntax-introducer))
    (check-language lang (and who (syntax-e who)))
    (define maker (redex-obj-maker who name base params vals defn))
    (define-values (name* defn*) (maker sc lang))
    (define name** (syntax-property name* 'not-free-identifier=? #t))
    #`(begin
        #,defn*
        (define-syntax #,name
          (redex-obj #'#,name**
                     (list #'#,who
                           #'#,name
                           #'#,base
                           #'#,params
                           #'#,vals
                           #'((... ...) #,defn))
                     (make-free-id-table)))
        (begin-for-syntax
          (redex-obj-add-ext! #'#,name #'#,base #'#,lang))))

  (define (check-language stx sym)
    (language-id-nts stx (or sym 'check-language)))

  (define (make-params params vals sc lang)
    (for/list ([param (in-syntax params)]
               [val (in-syntax vals)])
      (cons (sc param)
            (or (lang-extension val lang)
                (lift val lang)))))

  (define (lang-extension val lang)
    (define exts (redex-obj-exts (redex-obj-get val)))
    (define val* (free-id-table-ref exts lang (lambda _ #f)))
    (and val* (list val* #'(void))))

  (define (lift id lang)
    (define args (redex-obj-args (redex-obj-get id)))
    (define sc (make-syntax-introducer))
    (define-values (lifted-id lifted-defn)
      ((apply redex-obj-maker args) sc lang))
    (list lifted-id lifted-defn))

  (define (redex-obj-get id)
    (define-values (obj _)
      (syntax-local-value/immediate id (lambda _ (values #f #f))))
    (unless (redex-obj? obj)
      (raise-syntax-error
       #f
       "not defined as liftable; use the * version of define"
       id))
    obj)

  (define (redex-obj-base obj)
    (match (redex-obj-args obj)
      [(list _who _name base _params _vals _defn) base]))

  ;; Upstream registers an extension only with its immediate base.  The
  ;; selected staged-row path additionally registers it with every ancestor.
  ;; A dependency nested inside multiple extension layers can therefore find
  ;; the latest exact-language interpretation without flattening semantic
  ;; rules or changing the upstream package used by the frozen generator.
  (define (redex-obj-add-ext! name base lang)
    (when (syntax-e base)
      (define base-object (redex-obj-get base))
      (free-id-table-set! (redex-obj-exts base-object) lang name)
      (redex-obj-add-ext! name (redex-obj-base base-object) lang))))

(define-syntax-rule (define-reduction-relation ?name ?more ...)
  (define ?name (reduction-relation ?more ...)))

(define-syntax-rule (define-extended-reduction-relation ?name ?more ...)
  (define ?name (extend-reduction-relation ?more ...)))

(define-syntax (define-reduction-relation* stx)
  (syntax-parse stx
    [(?who:id ?name:id ?lang:id ?p:params ?more ...)
     (redex-obj-syntax #'?who
                       #'?name
                       #f
                       #'?lang
                       #'(?p.param ...)
                       #'(?p.val ...)
                       #'(define-reduction-relation ?name
                           *LANG* ?more ...))]))

(define-syntax (define-extended-reduction-relation* stx)
  (syntax-parse stx
    [(?who:id ?name:id ?base:id ?lang:id ?p:params ?more ...)
     (redex-obj-syntax #'?who
                       #'?name
                       #'?base
                       #'?lang
                       #'(?p.param ...)
                       #'(?p.val ...)
                       #'(define-extended-reduction-relation ?name
                           *BASE* *LANG* ?more ...))]))

(define-syntax-rule (define-extended-metafunction ?more ...)
  (define-metafunction/extension ?more ...))

(define-syntax (define-metafunction* stx)
  (syntax-parse stx
    [(?who:id ?lang:id ?p:params ?name:id ?more ...)
     (redex-obj-syntax #'?who
                       #'?name
                       #f
                       #'?lang
                       #'(?p.param ...)
                       #'(?p.val ...)
                       #'(define-metafunction
                           *LANG* ?name ?more ...))]))

(define-syntax (define-extended-metafunction* stx)
  (syntax-parse stx
    [(?who:id ?base:id ?lang:id ?p:params ?name:id ?more ...)
     (redex-obj-syntax #'?who
                       #'?name
                       #'?base
                       #'?lang
                       #'(?p.param ...)
                       #'(?p.val ...)
                       #'(define-extended-metafunction
                           *BASE* *LANG* ?name ?more ...))]))

(define-syntax (define-judgment-form* stx)
  (syntax-parse stx
    [(?who:id ?lang:id ?p:params #:mode ?m:mode ?more ...)
     #:with ?name #'?m.name
     (redex-obj-syntax #'?who
                       #'?name
                       #f
                       #'?lang
                       #'(?p.param ...)
                       #'(?p.val ...)
                       #'(define-judgment-form
                           *LANG* #:mode ?m ?more ...))]))

(define-syntax (define-extended-judgment-form* stx)
  (syntax-parse stx
    [(?who:id ?base:id ?lang:id #:mode ?m:mode ?p:params ?more ...)
     #:with ?name #'?m.name
     (redex-obj-syntax #'?who
                       #'?name
                       #'?base
                       #'?lang
                       #'(?p.param ...)
                       #'(?p.val ...)
                       #'(define-extended-judgment-form
                           *LANG* *BASE* #:mode ?m ?more ...))]))
