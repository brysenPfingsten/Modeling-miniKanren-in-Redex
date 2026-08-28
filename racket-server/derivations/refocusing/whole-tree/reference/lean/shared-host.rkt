#lang racket

(provide x-symbol?
         u-symbol?
         logical-vars-in
         fresh-u-list
         fresh-extension?
         distinct-names?
         cell-label->redex-name/host
         redex-name->cell-label/host)

(define (x-symbol? value)
  (and (symbol? value)
       (regexp-match? #rx"^x:" (symbol->string value))))

(define (u-symbol? value)
  (and (symbol? value)
       (regexp-match? #rx"^u:" (symbol->string value))))

;; Lean allocation observes only runtime names that occur in its own complete
;; frontier.  There is deliberately no hidden ownership or cached support.
(define (logical-vars-in datum [vars '()])
  (match datum
    [(? u-symbol? u)
     (if (member u vars) vars (cons u vars))]
    [(cons first rest)
     (logical-vars-in first (logical-vars-in rest vars))]
    [_ vars]))

(define (fresh-u-symbol used [n 0])
  (define candidate
    (string->symbol (format "u:~a" n)))
  (if (member candidate used)
      (fresh-u-symbol used (add1 n))
      candidate))

(define (fresh-u-list used lexical)
  (define-values (reversed _used)
    (for/fold ([reversed '()]
               [used* used])
              ([_x (in-list lexical)])
      (define u (fresh-u-symbol used*))
      (values (cons u reversed)
              (cons u used*))))
  (reverse reversed))

(define (distinct-names? names)
  (= (length names)
     (length (remove-duplicates names))))

(define (fresh-extension? introduced outer)
  (and (distinct-names? introduced)
       (for/and ([name (in-list introduced)])
         (not (member name outer)))))

(define cell-labels
  '((finish-success core)
    (finish-failure core)
    (force-delay delay)
    (commit-choice-answer disj)
    (commit-right-choice-answer search-join)
    (allocate-fresh core)
    (expand-conjunction core)
    (expand-disjunction disj)
    (suspend-goal delay)
    (conj-return core)
    (conj-fail core)
    (bubble-delay-through-conj delay)
    (late-distribute-settled disj)
    (late-distribute-right-settled search-join)
    (skip-left-failure disj)
    (rail-enter-right search-join)
    (reassociate-left-result disj)
    (skip-right-failure search-join)
    (rail-return-left search-join)
    (reassociate-right-result search-join)))

(define (cell-label->redex-name/host label)
  (and (member label cell-labels)
       (match label
         [(list name owner)
          (format "~a/~a" name owner)])))

(define (redex-name->cell-label/host name)
  (for/first ([label (in-list cell-labels)]
              #:when (equal? name
                             (cell-label->redex-name/host label)))
    label))
