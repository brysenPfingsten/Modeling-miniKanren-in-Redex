#lang racket

(require racket/runtime-path
         rackunit
         rackunit/text-ui)

(provide GENERATED-CORE-STAGE-DEPENDENCIES)

(define-runtime-path source-framework-file
  "../../../framework/core-source-schema.rkt")
(define-runtime-path framework-file "../../../framework/core-stage-schema.rkt")
(define-runtime-path renderer-file "../../../framework/core-stage-renderers.rkt")
(define-runtime-path policy-file "./policy.rkt")
(define-runtime-path s-file "./s.rkt")
(define-runtime-path e-file "./e.rkt")
(define-runtime-path n-file "./n.rkt")
(define-runtime-path corpus-file "./corpus.rkt")
(define-runtime-path vertical-file "./vertical.rkt")
(define-runtime-path transformation-test-file
  "./vertical-transformation-tests.rkt")
(define-runtime-path transport-test-file
  "./vertical-transport-diagnostics-tests.rkt")

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

(define (source-tail contents start-marker)
  (match
    (regexp-match-positions
     (regexp (regexp-quote start-marker))
     contents)
    [(list (cons start _end)) (substring contents start)]
    [#f
     (error 'source-tail "could not find marker ~e" start-marker)]))

(define-test-suite GENERATED-CORE-STAGE-DEPENDENCIES
  (test-case "selected stage implementations have one-way dependencies"
    (for ([path (in-list (append (list policy-file
                                       source-framework-file
                                       framework-file
                                       renderer-file
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
              '("define-selected-decomposition-stage"
                "define-selected-refocused-stage"
                "define-selected-machine-isomorphism-stage"
                "define-selected-compressed-stage"
                "define-selected-fixed-point-stage"))])
        (check-equal?
         (match-count
          (regexp (regexp-quote (string-append "(" stage-form)))
          contents)
         1))
      (for ([role
             (in-list
              '("generated-stage-plug-D"
                "generated-stage-decompose"
                "generated-stage-refocus-phase"
                "generated-stage-machineize"
                "generated-stage-compress"
                "generated-stage-promote-B/direct"))])
        (check-true
         (regexp-match?
          (regexp (regexp-quote (string-append role suffix)))
          contents)))))

  (test-case "one shared policy serves S, E, and N"
    (define policy-contents (file->string policy-file))
    (check-equal?
     (match-count #px"[(]define-selected-compression-policy\\s"
                  policy-contents)
     1)
    (for ([path (in-list row-files)])
      (define contents (file->string path))
      (check-equal?
       (match-count #rx"#:policy generated-core-compression-policy"
                    contents)
       1)
      (check-false
       (regexp-match? #rx"define-selected-compression-policy" contents))))

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

  (test-case "Redex dependencies are lexical while representation selection is static"
    (define redex-parameter-module (string-append "redex/" "parameter"))
    ;; Only the selected renderer lifts rule dependencies.  Source/row/edge
    ;; declarations do not use Redex parameters to select a representation.
    (check-true
     (regexp-match?
      (regexp (regexp-quote redex-parameter-module))
      (file->string renderer-file)))
    (for ([path (in-list (append (list source-framework-file
                                       framework-file
                                       policy-file
                                       vertical-file)
                                 row-files))])
      (define contents (file->string path))
      (check-false
       (regexp-match? (regexp (regexp-quote redex-parameter-module))
                      contents)))
    (for ([path (in-list (append (list source-framework-file
                                       framework-file
                                       renderer-file
                                       policy-file
                                       vertical-file)
                                 row-files))])
      (define contents (file->string path))
      (check-false (regexp-match? #px"[(]parameterize(?=[[:space:]])"
                                  contents))
      (check-false (regexp-match? #rx"dynamic-require" contents))
      (check-false (regexp-match? #rx"runtime representation selector"
                                  contents))
      (check-false
       (regexp-match? #rx"#:environment" contents)
       (format "selected architecture exposes #:environment in ~a" path))))

  (test-case "each phase renderer owns a direct Q map and its primary law"
    (define renderer-contents (file->string renderer-file))
    (define vertical-contents (file->string vertical-file))
    (for ([map-form
           (in-list
            '("define-decomposition-representation-map"
              "define-refocused-representation-map"
              "define-machine-representation-map"
              "define-compressed-representation-map"
              "define-fixed-point-representation-map"))])
      (check-equal?
       (match-count
        (regexp
         (regexp-quote (string-append "(define-syntax (" map-form)))
        renderer-contents)
       1
       (format "one renderer definition for ~a" map-form))
      (check-equal?
       (match-count
        (regexp (regexp-quote (string-append "(" map-form)))
        vertical-contents)
       3
       (format "SE, EN, and direct SN use ~a" map-form)))

    ;; Inspect the generated map bodies themselves, not a codec-derived
    ;; comparator.  Each body consumes only the joint representation views.
    (define direct-map-bodies
      (for/list
          ([markers
            (in-list
             (list
              (list "(define (Q-D decomposition)"
                    "(define (commutes frontier)")
              (list "(define (Q-Z refocused)"
                    "(define (commutes decomposition)")
              (list "(define (Q-M machine)"
                    "(define (commutes refocused)")
              (list "(define (Q-B compressed)"
                    "(define (commutes machine)")
              (list "(define (Q-Big big)"
                    "(define (commutes compressed)")))])
        (match-define (list start end) markers)
        (source-slice renderer-contents start end)))
    (for* ([body (in-list direct-map-bodies)]
           [forbidden
            (in-list
             '("source-decompose"
               "target-decompose"
               "source-phase"
               "target-phase"
               "plug-D"
               "decode"
               "encode"
               "readback"))])
      (check-false
       (regexp-match? (regexp (regexp-quote forbidden)) body)
       (format "direct map body contains transport token ~a" forbidden)))
    (for* ([body (in-list direct-map-bodies)]
           [concrete (in-list '("(Owner " "(Owners" "(Support"))])
      (check-false
       (regexp-match? (regexp (regexp-quote concrete)) body)
       (format "direct map body specializes representation case ~a"
               concrete)))
    (define representation-map-renderers
      (source-tail
       renderer-contents
       ";; Each representation-map macro belongs to one stage transformer"))
    (check-true
     (regexp-match? #rx"[(]build-derivations"
                    representation-map-renderers))
    (check-false
     (regexp-match? #rx"remove-duplicates" representation-map-renderers))
    (for ([forbidden
           (in-list
            '("/transport"
              "core-stage-q.rkt"
              "generated-stage-Z->D"
              "generated-stage-decode-MZ"
              "generated-stage-decode-BM"
              "generated-stage-readback"))])
      (check-false
       (regexp-match? (regexp (regexp-quote forbidden)) vertical-contents)
       (format "selected vertical module uses diagnostic route ~a"
               forbidden))))

  (test-case "M has a visibly generated direct transition system"
    (define contents (file->string renderer-file))
    (define direct-M
      (source-slice
       contents
       "#:contract (step-direct M RuleName M)"
       "#:contract (corresponds Z M)"))
    (check-true (regexp-match? #rx"native-step-clause" direct-M))
    (check-false (regexp-match? #rx"decode-MZ" direct-M))
    (check-false (regexp-match? #rx"Z-step" direct-M))
    (for ([path (in-list row-files)])
      (define public-provides
        (source-slice (file->string path)
                      "(provide"
                      "(module+ diagnostics"))
      (check-true
       (regexp-match? #rx"generated-stage-machine-step/direct"
                      public-provides))))

  (test-case "direct S to N stage maps do not route through E"
    (define contents (file->string vertical-file))
    (define direct-SN
      (source-slice
       contents
       ";; Direct S-to-N maps consume only S and N views/stages."
       "(define (Q-SN/D-composition/stages?"))
    (check-false (regexp-match? #rx"source:Q-SE" direct-SN))
    (check-false (regexp-match? #rx"source:Q-EN" direct-SN))
    (check-false (regexp-match? #rx"e:core/stage" direct-SN))
    (check-false (regexp-match? #rx"remove-duplicates" contents)))

  (test-case "codec and readback transport is test-only and secondary"
    (define primary-contents (file->string transformation-test-file))
    (define secondary-contents (file->string transport-test-file))
    (for ([diagnostic
           (in-list
            '("generated-stage-plug-D"
              "generated-stage-D->Z"
              "generated-stage-Z->D"
              "generated-stage-encode-ZM"
              "generated-stage-decode-MZ"
              "generated-stage-D->M"
              "generated-stage-M->D"
              "generated-stage-encode-MB"
              "generated-stage-decode-BM"
              "generated-stage-readback"
              "/transport"))])
      (check-false
       (regexp-match? (regexp (regexp-quote diagnostic)) primary-contents)
       (format "primary law suite uses diagnostic path ~a" diagnostic)))
    (for ([diagnostic
           (in-list
            '("generated-stage-plug-D"
              "generated-stage-Z->D"
              "generated-stage-decode-MZ"
              "generated-stage-decode-BM"
              "generated-stage-readback"))])
      (check-true
       (regexp-match? (regexp (regexp-quote diagnostic)) secondary-contents)
       (format "secondary suite exercises diagnostic path ~a" diagnostic)))
    (for ([path (in-list row-files)])
      (define contents (file->string path))
      (define public-provides
        (source-slice contents "(provide" "(module+ diagnostics"))
      (define diagnostic-provides
        (source-slice contents
                      "(module+ diagnostics"
                      "(check-redundancy"))
      (for ([diagnostic
             (in-list
              '("generated-stage-Z->D"
                "generated-stage-plug-D"
                "generated-stage-decode-MZ"
                "generated-stage-decode-BM"
                "generated-stage-readback"
                "generated-stage-refocus/spec"
                "generated-stage-refocused-step/spec"
                "generated-stage-ZM-corresponds"
                "generated-stage-machine-step/spec"
                "generated-stage-ZM-step-square"
                "generated-stage-MB-corresponds"
                "generated-stage-compressed-step/spec"
                "generated-stage-MB-step-square"))])
        (check-false
         (regexp-match? (regexp (regexp-quote diagnostic)) public-provides)
         (format "row exports diagnostic ~a publicly in ~a"
                 diagnostic path))
        (check-true
         (regexp-match? (regexp (regexp-quote diagnostic))
                        diagnostic-provides)
         (format "row omits diagnostic submodule export ~a in ~a"
                 diagnostic path)))))

  (test-case "corpus keys every representative by RuleName"
    (define contents (file->string corpus-file))
    (check-true (regexp-match? #rx"[(]define [(]row-source-ref" contents))
    (check-true (regexp-match? #rx"[(]assoc rule-name" contents))
    (check-true (regexp-match? #rx"SPARSE-VERTICAL-WITNESS/E" contents))
    (check-true (regexp-match? #rx"SPARSE-VERTICAL-WITNESS/N" contents))))

(module+ test
  (run-tests GENERATED-CORE-STAGE-DEPENDENCIES))
