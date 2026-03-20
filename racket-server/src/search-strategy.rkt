#lang racket

(require racket/match)

(provide search-strategy
         search-strategy?
         search-strategy-hoist
         search-strategy-scheduler
         default-search-strategy
         all-surfaced-search-strategies
         search-strategy->jsexpr
         normalize-search-strategy)

(struct search-strategy (hoist scheduler) #:transparent)

(define default-search-strategy
  (search-strategy "early" "rail"))

(define all-surfaced-search-strategies
  (list (search-strategy "early" "dfs")
        (search-strategy "late" "dfs")
        (search-strategy "early" "flip")
        (search-strategy "late" "flip")
        (search-strategy "early" "rail")
        (search-strategy "late" "rail")))

(define (search-strategy->jsexpr strategy)
  (hasheq 'hoist (search-strategy-hoist strategy)
          'scheduler (search-strategy-scheduler strategy)))

(define (normalize-axis maybe-value valid-values key)
  (match maybe-value
    [#f #f]
    [`,v #:when (member v valid-values) v]
    [_ (error 'normalize-search-strategy
              "invalid searchStrategy.~a ~e; expected one of ~e"
              key
              maybe-value
              valid-values)]))

(define (normalize-search-strategy maybe-strategy)
  (match maybe-strategy
    [#f default-search-strategy]
    [(? search-strategy?) maybe-strategy]
    [(? hash? strategy)
     (match (list (normalize-axis (hash-ref strategy 'hoist #f)
                                  '("early" "late")
                                  'hoist)
                  (normalize-axis (hash-ref strategy 'scheduler #f)
                                  '("dfs" "flip" "rail")
                                  'scheduler))
       [(list (? string? hoist)
              (? string? scheduler))
        (search-strategy hoist scheduler)]
       [_ (error 'normalize-search-strategy
                 "searchStrategy must contain hoist and scheduler")])]
    [_ (error 'normalize-search-strategy
              "searchStrategy must be a hash or search-strategy, got ~e"
              maybe-strategy)]))
