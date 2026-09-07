#lang racket

(provide (struct-out search-strategy)
         (struct-out strict-search)
         default-search-strategy
         all-surfaced-search-strategies
         search-strategy->jsexpr
         normalize-search-strategy)

(struct search-strategy (scheduler) #:transparent)
(struct strict-search () #:transparent)

(define default-search-strategy
  (strict-search))

(define all-surfaced-search-strategies
  (list (search-strategy "dfs")
        (search-strategy "flip")
        (search-strategy "rail")))

(define/match (search-strategy->jsexpr strategy)
  [((strict-search))
   (hasheq 'model "strict")]
  [((search-strategy scheduler))
   (hasheq 'scheduler scheduler)])

(define valid-schedulers '("dfs" "flip" "rail"))

(define (normalize-scheduler maybe-scheduler)
  (match maybe-scheduler
    [(? string? scheduler)
     #:when (member scheduler valid-schedulers)
     scheduler]
    [_
     (error 'normalize-search-strategy
            "invalid searchStrategy.scheduler ~e; expected one of ~e"
            maybe-scheduler
            valid-schedulers)]))

(define (normalize-search-strategy maybe-strategy)
  (match maybe-strategy
    [#f default-search-strategy]
    [(strict-search) (strict-search)]
    [(search-strategy scheduler)
     (search-strategy (normalize-scheduler scheduler))]
    [(? hash? strategy)
     (when (hash-has-key? strategy 'hoist)
       (error 'normalize-search-strategy
              "searchStrategy.hoist is not part of the factored runtime"))
     (match (hash-ref strategy 'model #f)
       [#f (search-strategy
            (normalize-scheduler (hash-ref strategy 'scheduler #f)))]
       ["strict"
        (when (hash-has-key? strategy 'scheduler)
          (error 'normalize-search-strategy
                 "strict search has no scheduler selection"))
        (strict-search)]
       [model (error 'normalize-search-strategy
                     "invalid searchStrategy.model ~e; expected strict" model)])]
    [_ (error 'normalize-search-strategy
              "searchStrategy must be a hash, strict-search, or search-strategy, got ~e"
              maybe-strategy)]))
