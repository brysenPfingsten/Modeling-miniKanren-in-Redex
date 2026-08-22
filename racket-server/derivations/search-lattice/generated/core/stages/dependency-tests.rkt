#lang racket

(require racket/runtime-path
         rackunit
         rackunit/text-ui)

(provide GENERATED-CORE-STAGE-DEPENDENCIES)

(define-runtime-path framework-file "../../../framework/core-stage-schema.rkt")
(define-runtime-path Q-framework-file "../../../framework/core-stage-q.rkt")
(define-runtime-path policy-file "./policy.rkt")
(define-runtime-path s-file "./s.rkt")
(define-runtime-path e-file "./e.rkt")
(define-runtime-path n-file "./n.rkt")
(define-runtime-path corpus-file "./corpus.rkt")
(define-runtime-path vertical-file "./vertical.rkt")

(define row-files (list s-file e-file n-file))

(define (match-count pattern contents)
  (length (regexp-match* pattern contents)))

(define (source-slice contents start-marker end-marker)
  (define (marker-position marker)
    (match
      (regexp-match-positions
       (regexp (regexp-quote marker))
       contents)
      [(list (cons start _end)) start]
      [#f #f]))
  (define start (marker-position start-marker))
  (define end (marker-position end-marker))
  (unless (and start end (< start end))
    (error 'source-slice
           "could not find ordered markers ~e then ~e"
           start-marker
           end-marker))
  (substring contents start end))

(define-test-suite GENERATED-CORE-STAGE-DEPENDENCIES
  (test-case "selected stage implementations have one-way dependencies"
    (for ([path (in-list (append (list policy-file
                                       framework-file
                                       Q-framework-file
                                       vertical-file)
                                 row-files))])
      (define contents (file->string path))
      (for ([forbidden
             (in-list
              '("oracles/"
                "src/search-lattice"
                "core/s/"
                "core/e/"
                "generated/core/s/column"
                "generated/core/e/column"))])
        (check-false
         (regexp-match? (regexp (regexp-quote forbidden)) contents)
         (format "forbidden dependency ~a in ~a" forbidden path)))))

  (test-case "each row visibly consumes one source interface and five stages"
    (for ([entry
           (in-list
            (list (list s-file "generated-core-s-source" "/s")
                  (list e-file "generated-core-e-source" "/e")
                  (list n-file "generated-core-n-source" "/n")))])
      (match-define (list path source-interface suffix) entry)
      (define contents (file->string path))
      (check-equal?
       (match-count #px"[(]define-generated-core-stage-instance\\s"
                    contents)
       1)
      (check-true
       (regexp-match? (regexp (regexp-quote source-interface)) contents))
      (for ([stage-form
             (in-list
              '("define-decomposition-stage"
                "define-refocused-stage"
                "define-machine-isomorphism-stage"
                "define-compressed-stage"
                "define-fixed-point-stage"))])
        (check-equal?
         (match-count
          (regexp (regexp-quote (string-append "(" stage-form)))
          contents)
         1))
      (for ([role
             (in-list
              '("generated-stage-plug-D"
                "generated-stage-decompose"
                "generated-stage-D->Z"
                "generated-stage-Z->D"
                "generated-stage-encode-ZM"
                "generated-stage-decode-MZ"
                "generated-stage-encode-MB"
                "generated-stage-decode-BM"))])
        (check-true
         (regexp-match?
          (regexp (regexp-quote (string-append role suffix)))
          contents)))))

  (test-case "one shared policy serves S, E, and N"
    (define policy-contents (file->string policy-file))
    (check-equal?
     (match-count #px"[(]define-compression-policy\\s" policy-contents)
     1)
    (for ([path (in-list row-files)])
      (define contents (file->string path))
      (check-equal?
       (match-count #rx"#:policy generated-core-compression-policy"
                    contents)
       1)
      (check-false (regexp-match? #rx"define-compression-policy" contents))))

  (test-case "rows do not restate the thirteen semantic equations"
    (for ([path (in-list row-files)])
      (define contents (file->string path))
      (for ([label
             (in-list
              '(allocate-fresh
                conj-fail
                conj-return
                disequality-fail
                disequality-success
                expand-conjunction
                fail
                finish-failure
                finish-success
                succeed
                unify-fail
                unify-success
                unify-violates-disequality))])
        (check-false
         (regexp-match?
          (regexp
           (format "[\"']~a[\"']"
                   (regexp-quote (symbol->string label))))
          contents)))))

  (test-case "representation staging uses no dynamic selector or parameter"
    (define redex-parameter-module (string-append "redex/" "parameter"))
    (for ([path (in-list (append (list framework-file
                                       Q-framework-file
                                       policy-file
                                       vertical-file)
                                 row-files))])
      (define contents (file->string path))
      (check-false
       (regexp-match? (regexp (regexp-quote redex-parameter-module))
                      contents))
      (check-false (regexp-match? #px"[(]parameterize(?=[[:space:]])"
                                  contents))
      (check-false (regexp-match? #rx"dynamic-require" contents))
      (check-false (regexp-match? #rx"runtime representation selector"
                                  contents))))

  (test-case "direct stage Q maps are structural and transport stays separate"
    (define contents (file->string Q-framework-file))
    (for ([entry
           (in-list
            (list
             (list "(define (Q-D decomposition)"
                   "(define (Q-D/transport decomposition)"
                   '("source-plug-D" "target-decompose"))
             (list "(define (Q-Z refocused)"
                   "(define (Q-Z/transport refocused)"
                   '("source-Z->D" "target-D->Z"))
             (list "(define (Q-M machine)"
                   "(define (Q-M/transport machine)"
                   '("source-decode-MZ" "target-encode-ZM"))
             (list "(define (Q-B compressed)"
                   "(define (Q-B/transport compressed)"
                   '("source-decode-BM" "target-encode-MB"))))])
      (match-define (list start end forbidden) entry)
      (define direct-slice (source-slice contents start end))
      (for ([token (in-list forbidden)])
        (check-false
         (regexp-match? (regexp (regexp-quote token)) direct-slice))))
    (check-true (regexp-match? #rx"[(]build-derivations" contents))
    (check-false (regexp-match? #rx"remove-duplicates" contents))
    (for ([concrete (in-list '("(Owner " "(Owners" "(Support"))])
      (check-false
       (regexp-match? (regexp (regexp-quote concrete)) contents))))

  (test-case "direct S to N stage maps do not route through E"
    (define contents (file->string vertical-file))
    (define direct-SN
      (source-slice
       contents
       "#:Q-R source:Q-SN/generated"
       "(define (Q-SN/C-composition/stages?"))
    (check-false (regexp-match? #rx"source:Q-SE" direct-SN))
    (check-false (regexp-match? #rx"source:Q-EN" direct-SN))
    (check-false (regexp-match? #rx"remove-duplicates" contents)))

  (test-case "corpus keys every representative by RuleName"
    (define contents (file->string corpus-file))
    (check-true (regexp-match? #rx"[(]define [(]row-source-ref" contents))
    (check-true (regexp-match? #rx"[(]assoc rule-name" contents))
    (check-true (regexp-match? #rx"SPARSE-VERTICAL-WITNESS/E" contents))
    (check-true (regexp-match? #rx"SPARSE-VERTICAL-WITNESS/N" contents))))

(module+ test
  (run-tests GENERATED-CORE-STAGE-DEPENDENCIES))
