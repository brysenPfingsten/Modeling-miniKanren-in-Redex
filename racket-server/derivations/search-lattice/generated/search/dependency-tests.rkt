#lang racket

(require racket/list
         racket/runtime-path
         rackunit
         rackunit/text-ui
         redex/reduction-semantics
         (prefix-in delay: "../delay/corpus.rkt")
         (prefix-in disjunction: "../disjunction/corpus.rkt")
         (prefix-in production-search:
                    "../../../../src/search-lattice/reduction-relations/search-red.rkt")
         "corpus.rkt")

(provide GENERATED-SEARCH-DEPENDENCY-TESTS)

(define-runtime-path join-framework-file "../../framework/search-join-schema.rkt")
(define-runtime-path delay-framework-file "../../framework/delay-schema.rkt")
(define-runtime-path disjunction-framework-file
  "../../framework/disjunction-schema.rkt")
(define-runtime-path stage-framework-file
  "../../framework/core-stage-renderers.rkt")
(define-runtime-path source-s-file "source/s.rkt")
(define-runtime-path source-e-file "source/e.rkt")
(define-runtime-path source-n-file "source/n.rkt")
(define-runtime-path source-vertical-file "source/vertical.rkt")
(define-runtime-path reverse-source-s-file "source/feature-order/s.rkt")
(define-runtime-path reverse-source-e-file "source/feature-order/e.rkt")
(define-runtime-path reverse-source-n-file "source/feature-order/n.rkt")
(define-runtime-path stage-s-file "stages/s.rkt")
(define-runtime-path stage-e-file "stages/e.rkt")
(define-runtime-path stage-n-file "stages/n.rkt")
(define-runtime-path stage-vertical-file "stages/vertical.rkt")
(define-runtime-path reverse-stage-s-file "stages/feature-order/s.rkt")
(define-runtime-path reverse-stage-e-file "stages/feature-order/e.rkt")
(define-runtime-path reverse-stage-n-file "stages/feature-order/n.rkt")
(define-runtime-path corpus-file "corpus.rkt")
(define-runtime-path source-test-file "source-tests.rkt")
(define-runtime-path feature-order-test-file "feature-order-tests.rkt")
(define-runtime-path horizontal-file "horizontal-tests.rkt")
(define-runtime-path embedding-file "embedding-tests.rkt")
(define-runtime-path cube-file "cube-tests.rkt")
(define-runtime-path diagnostic-file "transport-diagnostics-tests.rkt")

(define source-row-files (list source-s-file source-e-file source-n-file))
(define reverse-source-row-files
  (list reverse-source-s-file reverse-source-e-file reverse-source-n-file))
(define stage-row-files (list stage-s-file stage-e-file stage-n-file))
(define reverse-stage-row-files
  (list reverse-stage-s-file reverse-stage-e-file reverse-stage-n-file))
(define public-implementation-files
  (append
   (list join-framework-file
         delay-framework-file
         disjunction-framework-file
         stage-framework-file
         source-vertical-file
         stage-vertical-file)
   source-row-files
   reverse-source-row-files
   stage-row-files
   reverse-stage-row-files))

(define evidence-files
  (list corpus-file source-test-file feature-order-test-file horizontal-file
        embedding-file cube-file diagnostic-file))

(define (match-count pattern contents)
  (length (regexp-match* pattern contents)))

(define (source-slice contents start-marker end-marker)
  (define (position marker [start 0])
    (match
      (regexp-match-positions
       (regexp (regexp-quote marker))
       contents
       start)
      [(list (cons start _end)) start]
      [#f #f]))
  (define start (position start-marker))
  (define end
    (and start
         (position end-marker (+ start (string-length start-marker)))))
  (unless (and start end (< start end))
    (error 'source-slice
           "could not find ordered markers ~e then ~e"
           start-marker
           end-marker))
  (substring contents start end))

(define GENERATED-SEARCH-DEPENDENCY-TESTS
  (test-suite
   "generated Search zero-rule dependency and architecture inventory"

   (test-case "Search exposes exactly the twenty-one inherited labels"
     (define expected
       (sort
        (append disjunction:CORE-RULE-NAMES
                delay:DELAY-OWNED-RULE-NAMES
                disjunction:DISJUNCTION-OWNED-RULE-NAMES)
        symbol<?))
     (check-equal? SEARCH-RULE-NAMES expected)
     (check-equal? (length SEARCH-RULE-NAMES) 21)
     (check-false (check-duplicates SEARCH-RULE-NAMES))
     (check-equal? SEARCH-FEATURE-RULE-NAMES
                   (append delay:DELAY-OWNED-RULE-NAMES
                           disjunction:DISJUNCTION-OWNED-RULE-NAMES)))

   ;; Production is only a secondary static-inventory oracle here.  This leaf
   ;; never steps it, so its whole-frontier allocation policy cannot define a
   ;; generated Q coordinate, trace, or proof multiplicity.
   (test-case "production confirms the twenty-one-label zero join delta"
     (define production-labels
       (for/list
           ([name
             (in-list
              (reduction-relation->rule-names production-search:search-red))])
         (string->symbol (~a name))))
     (check-equal? (length production-labels) 21)
     (check-equal? (sort production-labels symbol<?) SEARCH-RULE-NAMES)
     (for ([label (in-list SEARCH-RULE-NAMES)])
       (check-equal?
        (count (lambda (actual) (eq? actual label)) production-labels)
        1
        (format "production multiplicity for inherited label ~a" label))))

   (test-case "the explicit Search join is a representation-neutral zero-rule boundary"
     (define contents (file->string join-framework-file))
     (for ([required
            (in-list
             '("define-generated-search-join-source"
               "define-generated-search-join-stage-extension"
               "#:visit-search-join"
               "#:owned-rule-labels ()"
               "#:identity"
               "#:feature-singletons ()"))])
       (check-true
        (regexp-match? (regexp (regexp-quote required)) contents)
        (format "Search join schema lacks ~a" required)))
     (for ([forbidden
            (in-list
             '("reduction-relation"
               "suspend-goal"
               "force-delay"
               "expand-disjunction"
               "skip-left-failure"
               "commit-choice-answer"))])
       (check-false
        (regexp-match? (regexp (regexp-quote forbidden)) contents)
        (format "Search join schema owns concrete rule material ~a" forbidden))))

   (test-case "selected public modules do not depend on production or oracles"
     (for ([path (in-list public-implementation-files)])
       (define contents (file->string path))
       (for ([forbidden
              (in-list
               '("#:environment"
                 "#:lower-with"
                 "define-derivation-instance"
                 "stage-generators.rkt"
                 "generated/core/s/column"
                 "generated/core/e/column"
                 "oracles/"
                 "src/search-lattice"))])
         (check-false
          (regexp-match? (regexp (regexp-quote forbidden)) contents)
          (format "forbidden selected dependency ~a in ~a" forbidden path)))))

   (test-case "the zero-rule join introduces no scheduler policy"
     (for ([path (in-list (append (list join-framework-file)
                                  source-row-files
                                  reverse-source-row-files
                                  stage-row-files
                                  reverse-stage-row-files))])
       (define contents (file->string path))
       (for ([forbidden
              (in-list
               '("round-robin"
                 "schedule-next"
                 "dfs-step"
                 "flip-step"
                 "rail-step"
                 "scheduler-rule"))])
         (check-false
          (regexp-match? (regexp (regexp-quote forbidden)) contents)
          (format "scheduler token ~a in zero-rule module ~a"
                  forbidden
                  path)))))

   (test-case "canonical sources assemble Disjunction then Delay then the empty join"
     (for ([entry
            (in-list
             (list
              (list source-s-file "generated-disjunction-s-source"
                    "generated-search-s-child-source"
                    "generated-search-s-source")
              (list source-e-file "generated-disjunction-e-source"
                    "generated-search-e-child-source"
                    "generated-search-e-source")
              (list source-n-file "generated-disjunction-n-source"
                    "generated-search-n-child-source"
                    "generated-search-n-source")))])
       (match-define (list path base child joined) entry)
       (define contents (file->string path))
       (check-equal?
        (match-count #px"[(]define-generated-delay-source\\s" contents)
        1)
       (check-equal?
        (match-count #px"[(]define-generated-search-join-source\\s" contents)
        1)
       (for ([required (in-list (list base child joined "#:owned-rule-labels ()"))])
         (check-true
          (regexp-match? (regexp (regexp-quote required)) contents)
          (format "canonical source ~a lacks ~a" path required)))))

   (test-case "reverse sources independently assemble Delay then Disjunction"
     (for ([entry
            (in-list
             (list
              (list reverse-source-s-file "generated-delay-s-source"
                    "generated-search-reverse-s-child-source")
              (list reverse-source-e-file "generated-delay-e-source"
                    "generated-search-reverse-e-child-source")
              (list reverse-source-n-file "generated-delay-n-source"
                    "generated-search-reverse-n-child-source")))])
       (match-define (list path base child) entry)
       (define contents (file->string path))
       (check-equal?
        (match-count #px"[(]define-generated-disjunction-source\\s" contents)
        1)
       (check-equal?
        (match-count #px"[(]define-generated-search-join-source\\s" contents)
        1)
       (for ([required (in-list (list base child "#:owned-rule-labels ()"))])
         (check-true
          (regexp-match? (regexp (regexp-quote required)) contents)
          (format "reverse source ~a lacks ~a" path required)))))

   (test-case "both stage orders late-bind two children before one identity join"
     (for ([path (in-list (append stage-row-files reverse-stage-row-files))])
       (define contents (file->string path))
       (check-equal?
        (match-count #px"#:dependencies-from\\s+generated-search" contents)
        2
        (format "two late-bound child dependencies in ~a" path))
       (check-equal?
        (match-count #px"[(]define-generated-search-join-stage-extension\\s"
                     contents)
        1)
       (check-equal?
        (match-count #px"[(]apply-selected-stage-extension\\s" contents)
        3)
       (check-true
        (regexp-match? #px"#:feature-singletons \\(\\)"
                       (file->string join-framework-file)))))

   (test-case "direct S-to-N maps never route through E"
     (define source-contents (file->string source-vertical-file))
     (define source-direct
       (source-slice
        source-contents
        "(define (Q-SN/R/search frontier)"
        "(define (Q-SN/R-composition/search? frontier)"))
     (check-false (regexp-match? #rx"Q-SE" source-direct))
     (check-false (regexp-match? #rx"Q-EN" source-direct))
     (check-false (regexp-match? #rx"generated/search/e" source-direct))

     (define stage-contents (file->string stage-vertical-file))
     (define stage-direct
       (source-slice
        stage-contents
        "(define-search-representation-edge\n  s:search/staged-row/S n:search/staged-row/N"
        "(define (Q-SN/D-composition/stages/search? value)"))
     (check-false (regexp-match? #rx"Q-SE" stage-direct))
     (check-false (regexp-match? #rx"Q-EN" stage-direct))
     (check-false (regexp-match? #rx"e:search/staged-row" stage-direct)))

   (test-case "the Search corpus is API-neutral plain child data"
     (define contents (file->string corpus-file))
     (for ([required
            (in-list '("../delay/corpus.rkt" "../disjunction/corpus.rkt"))])
       (check-true (regexp-match? (regexp (regexp-quote required)) contents)))
     (for ([forbidden
            (in-list
             '("generated-search-"
               "define-generated-"
               "framework/"
               "oracles/"
               "src/search-lattice"
               "Q-SE"
               "Q-EN"
               "Q-SN"))])
       (check-false
        (regexp-match? (regexp (regexp-quote forbidden)) contents)
        (format "Search corpus constructs through forbidden API ~a" forbidden))))

   (test-case "proof and corpus evidence never deduplicates raw coordinates"
     (for ([path (in-list evidence-files)])
       (define contents (file->string path))
       (check-false
        (regexp-match? #rx"remove-duplicates" contents)
        (format "evidence deduplicates raw proofs in ~a" path))))))

(module+ test
  (run-tests GENERATED-SEARCH-DEPENDENCY-TESTS))
