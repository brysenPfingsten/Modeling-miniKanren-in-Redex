#lang racket

(require redex/reduction-semantics
         (only-in "./delay-red.rkt"
                  delay-local/base
                  delay-frontier/base)
         (only-in "./disj-base-red.rkt"
                  disj-base-core
                  disj-goal-local/under-QSpine
                  disj-frontier/local-base))

(provide search-base-pre-red)

(check-redundancy #t)

(require "../languages/search-base-lang.rkt")

(define lifted-disj-base-core
  (extend-reduction-relation disj-base-core search-base-lang))

(define lifted-disj-goal-local/under-QSpine
  (extend-reduction-relation disj-goal-local/under-QSpine search-base-lang))

(define lifted-disj-frontier/local-base
  (extend-reduction-relation disj-frontier/local-base search-base-lang))

(define lifted-delay-local/base
  (extend-reduction-relation delay-local/base search-base-lang))

(define delay-local/under-QSpine
  (context-closure lifted-delay-local/base search-base-lang QSpine))

(define lifted-delay-frontier/base
  (extend-reduction-relation delay-frontier/base search-base-lang))

(define lifted-disj-frontier/under-QFront
  (context-closure lifted-disj-frontier/local-base search-base-lang QFront))

(define search-base-bounced-frontier/base
  (reduction-relation
   search-base-lang
   #:domain cfg
   [--> (in-hole QSpine (Bounced (in-hole QFront ((promoted_i <-+ search_mid) <-+ search_right))))
        (in-hole QSpine (Bounced (in-hole QFront (promoted_i <-+ (search_mid <-+ search_right)))))
        "search-base/reassociate-left-answer"]
   [--> (in-hole QSpine (Bounced (in-hole QFront (promoted_i <-+ search_right))))
        (in-hole QSpine (in-hole QFront (promoted_i + (Bounced search_right))))
        "search-base/promote-left-answer"]
   [--> (in-hole QSpine (Bounced (in-hole QFront (((empty-tree) <-+ search_mid) <-+ search_right))))
        (in-hole QSpine (Bounced (in-hole QFront (search_mid <-+ search_right))))
        "search-base/erase-left-fail"]
   [--> (in-hole QSpine (Bounced (in-hole QFront ((empty-tree) <-+ search_right))))
        (in-hole QSpine (in-hole QFront (Bounced search_right)))
        "search-base/erase-left-fail-top"]))

(define search-base-pre-red
  (union-reduction-relations
   lifted-disj-base-core
   delay-local/under-QSpine
   lifted-delay-frontier/base
   lifted-disj-goal-local/under-QSpine
   lifted-disj-frontier/under-QFront
   search-base-bounced-frontier/base))
