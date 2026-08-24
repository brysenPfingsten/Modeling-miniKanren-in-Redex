#lang racket

(require racket/runtime-path
         rackunit
         rackunit/text-ui)

(provide GENERATED-CORE-SOURCE-DEPENDENCIES)

(define-runtime-path source-root ".")
(define-runtime-path framework-file "../../../framework/core-source-schema.rkt")
(define-runtime-path stage-framework-file
  "../../../framework/core-stage-schema.rkt")
(define-runtime-path s-file "./s.rkt")
(define-runtime-path e-file "./e.rkt")
(define-runtime-path n-file "./n.rkt")
(define-runtime-path vertical-file "./vertical.rkt")
(define-runtime-path comparison-file "./comparison-tests.rkt")

(define row-files (list s-file e-file n-file))
(define implementation-files
  (list framework-file s-file e-file n-file vertical-file))
(define selected-interface-files
  (cons stage-framework-file implementation-files))

(define CORE-RULE-LABELS
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
    unify-violates-disequality))

(define (source-slice path start-marker end-marker)
  (define contents (file->string path))
  (define (marker-start marker)
    (match
      (regexp-match-positions
       (regexp (regexp-quote marker))
       contents)
      [(list (cons start _end)) start]
      [#f #f]))
  (define start (marker-start start-marker))
  (define end (marker-start end-marker))
  (unless (and start end (< start end))
    (error 'source-slice
           "could not find ordered markers in ~a: ~e then ~e"
           path
           start-marker
           end-marker))
  (substring contents start end))

(define (match-count pattern contents)
  (length (regexp-match* pattern contents)))

(define-test-suite GENERATED-CORE-SOURCE-DEPENDENCIES
  (test-case "generated rows do not import an oracle or legacy implementation"
    (for ([path (in-list row-files)])
      (define contents (file->string path))
      (for ([forbidden
             (in-list
              '("oracles/"
                "src/search-lattice"
                "stage-generators"
                "generated/core/s/column"
                "generated/core/e/column"
                "core/s/"
                "core/e/"))])
        (check-false
         (regexp-match? (regexp (regexp-quote forbidden)) contents)
         (format "forbidden dependency ~a in ~a" forbidden path)))))

  (test-case "representation selection uses neither Redex nor Racket parameters"
    (define redex-parameter-module
      (string-append "redex/" "parameter"))
    (for ([path (in-list implementation-files)])
      (define contents (file->string path))
      (check-false
       (regexp-match? (regexp (regexp-quote redex-parameter-module))
                      contents))
      (check-false (regexp-match? #px"[(]parameterize(?=[[:space:]])"
                                  contents))
      (check-false (regexp-match? #rx"AllocateEvent" contents)))
    ;; The selected interface consumes explicit variable, live-state,
    ;; returned, failure-summary, terminal, and payload/context views.  Neither
    ;; its public rows nor either side of its bridge may lower those views back
    ;; into the frozen prototype descriptor.
    (for ([path (in-list selected-interface-files)])
      (define contents (file->string path))
      (for ([forbidden
             (in-list
              '("#:environment"
                "#:lower-with"
                "define-derivation-instance"
                "stage-generators.rkt"))])
        (check-false
         (regexp-match? (regexp (regexp-quote forbidden)) contents)
         (format "selected interface contains prototype lowering ~a in ~a"
                 forbidden
                 path)))))

  (test-case "the core schema is representation-neutral and owns no stage renderer"
    (define contents (file->string framework-file))
    (for ([forbidden
           (in-list
            '("stage-generators.rkt"
              "decomposition-instance.rkt"
              "define-selected-decomposition-stage"
              "define-selected-refocused-stage"
              "define-selected-machine-isomorphism-stage"
              "define-selected-compressed-stage"
              "define-selected-fixed-point-stage"
              "(Owner "
              "(Owners"
              "(Support"
              "u:"))])
      (check-false
       (regexp-match? (regexp (regexp-quote forbidden)) contents)
       (format "framework contains forbidden concrete/stage token ~a"
               forbidden)))
    (for ([introspection
           (in-list '("language-nts"
                      "compiled-language?"
                      "language-nonterminals"
                      "runtime representation selector"))])
      (check-false
       (regexp-match? (regexp (regexp-quote introspection)) contents))))

  (test-case "the thirteen semantic equations occur only in the core schema"
    (for ([path (in-list row-files)])
      (define contents (file->string path))
      (for ([label (in-list CORE-RULE-LABELS)])
        (check-false
         (regexp-match?
          (regexp
           (format "\"~a\"" (regexp-quote (symbol->string label))))
          contents)
         (format "row ~a restates semantic rule ~a" path label))))
    ;; CP4 stores each semantic equation once in a representation-neutral IR;
    ;; R and the explicit selected stage view are two renderers of that IR.
    (define framework-contents (file->string framework-file))
    (for ([label (in-list CORE-RULE-LABELS)])
      (check-equal?
       (match-count
        (regexp
         (format "\"~a\"" (regexp-quote (symbol->string label))))
        framework-contents)
       1))
    (check-true (regexp-match? #rx"[(]define semantic-rules"
                               framework-contents))
    (check-true (regexp-match? #rx"[(]define selected-stage-view"
                               framework-contents))
    (check-true (regexp-match? #rx"#,@work-R-rules"
                               framework-contents))
    (check-true (regexp-match? #rx"#,@stage-rules"
                               framework-contents)))

  (test-case "candidate modules visibly instantiate one static source row"
    (for ([triple
           (in-list
            (list (list s-file
                        "core-s-representation-strategy"
                        "generated-core-s-lang"
                        "generated-core-s-red"
                        "wf-core/generated/s?"
                        "generated-core-s-source")
                  (list e-file
                        "core-e-representation-strategy"
                        "generated-core-e-lang"
                        "generated-core-e-red"
                        "wf-core/generated/e?"
                        "generated-core-e-source")
                  (list n-file
                        "core-n-representation-strategy"
                        "generated-core-n-lang"
                        "generated-core-n-red"
                        "wf-core/generated/n?"
                        "generated-core-n-source")))])
      (match-define
        (list path strategy language relation wf-root source-interface)
        triple)
      (define contents (file->string path))
      (check-equal?
       (match-count #px"[(]define-core-representation-strategy\\s"
                    contents)
       1)
      (check-equal?
       (match-count #px"[(]define-generated-core-source\\s" contents)
       1)
      (for ([binding
             (in-list
              (list strategy
                    language
                    relation
                    wf-root
                    source-interface))])
        (check-true
         (regexp-match? (regexp (regexp-quote binding)) contents)))))

  (test-case "carrier templates expose the selected phase ownership"
    (define s-contents (file->string s-file))
    (define e-contents (file->string e-file))
    (define n-contents (file->string n-file))
    (for ([witness
           (in-list
            '("#:state (state sub dis trail tag)"
              "#:work (Work supply g sigma)"
              "#:conj (Conj supply W g)"
              "#:answer (Answer supply sigma)"
              "#:last (Last supply A)"))])
      (check-true
       (regexp-match? (regexp (regexp-quote witness)) s-contents)))
    (for ([contents (in-list (list e-contents n-contents))])
      (for ([witness
             (in-list
              '("#:state (state supply sub dis trail tag)"
                "#:work (Work g sigma)"
                "#:conj (Conj W g)"
                "#:answer (Answer sigma)"
                "#:last (Last A)"
                "#:dead (Dead supply)"
                "#:done (Done supply)"))])
        (check-true
         (regexp-match? (regexp (regexp-quote witness)) contents)))
      (check-false (regexp-match? #rx"[(]Work supply g sigma[)]"
                                  contents))
      (check-false (regexp-match? #rx"[(]Conj supply W g[)]"
                                  contents))))

  (test-case "S allocation is active-path-sensitive and branch copy is real"
    (define s-contents (file->string s-file))
    (check-true
     (regexp-match? #rx"work-focus-prefix-support/generated/s"
                    s-contents))
    (check-true
     (regexp-match?
      (regexp
       (regexp-quote
        "(term (WORK-FOCUS-PREFIX-HOOK WorkFocus ()))"))
      s-contents))
    (check-false (regexp-match? #rx"whole-frontier" s-contents))
    (for ([path (in-list row-files)])
      (define contents (file->string path))
      (check-true (regexp-match? #rx"#:branch-copy-supply" contents))
      (check-true (regexp-match? #rx"#:branch-copy branch-copy/generated/"
                                 contents))))

  (test-case "direct generated Q_SN does not call an adjacent map"
    (define direct-map
      (source-slice
       framework-file
       ";; The direct map deliberately consumes S's export."
       "(define (#,composition-id frontier)"))
    (check-true (regexp-match? #rx"#,n-rebuild [(]#,s-export frontier[)]"
                               direct-map))
    (check-false (regexp-match? #rx"#,q-se-id" direct-map))
    (check-false (regexp-match? #rx"#,q-en-id" direct-map)))

  (test-case "phase Q hooks are explicit and every direct Q_SN bypasses E"
    (for ([path (in-list row-files)])
      (define contents (file->string path))
      (for ([hook
             (in-list
              '("#:focus-export"
                "#:focus-rebuild"
                "#:root-focus-export"
                "#:root-focus-rebuild"
                "#:failure-focus-export"
                "#:failure-focus-rebuild"
                "#:terminal-export"
                "#:terminal-rebuild"))])
        (check-true
         (regexp-match? (regexp (regexp-quote hook)) contents))))
    (define vertical-contents (file->string vertical-file))
    (for ([entry
           (in-list
            (list
             (list "focus" "focused focus" "q-focus")
             (list "root-focus" "frontier spine" "q-root-focus")
             (list "failure-focus" "summary focus" "q-failure-focus")
             (list "terminal" "terminal" "q-terminal")))])
      (match-define (list phase arguments hook-prefix) entry)
      (define direct-map
        (source-slice
         vertical-file
         (format "(define (Q-SN/~a/generated ~a)" phase arguments)
         (format "(define (Q-SN/~a-composition/generated? ~a)"
                 phase
                 arguments)))
      (check-true
       (regexp-match?
        (regexp (regexp-quote (string-append hook-prefix "-export/generated/s")))
        direct-map))
      (check-true
       (regexp-match?
        (regexp (regexp-quote (string-append hook-prefix "-rebuild/generated/n")))
        direct-map))
      (check-false
       (regexp-match?
        (regexp (regexp-quote (string-append "Q-SE/" phase)))
        direct-map))
      (check-false
       (regexp-match?
        (regexp (regexp-quote (string-append "Q-EN/" phase)))
        direct-map)))
    (for ([name
           (in-list
            '(Q-SE/focus/generated
              Q-EN/focus/generated
              Q-SN/focus/generated
              Q-SN/focus-composition/generated?
              Q-SE/root-focus/generated
              Q-EN/root-focus/generated
              Q-SN/root-focus/generated
              Q-SN/root-focus-composition/generated?
              Q-SE/failure-focus/generated
              Q-EN/failure-focus/generated
              Q-SN/failure-focus/generated
              Q-SN/failure-focus-composition/generated?
              Q-SE/terminal/generated
              Q-EN/terminal/generated
              Q-SN/terminal/generated
              Q-SN/terminal-composition/generated?))])
      (check-true
       (regexp-match?
        (regexp (regexp-quote (symbol->string name)))
        vertical-contents))))

  (test-case "only the comparison module imports candidates and oracles"
    (define comparison-contents (file->string comparison-file))
    (check-true (regexp-match? #rx"[.]?/s[.]rkt" comparison-contents))
    (check-true (regexp-match? #rx"oracles/core/s" comparison-contents))
    (for ([path (in-list implementation-files)])
      (define contents (file->string path))
      (check-false
       (and (regexp-match? #rx"oracles/core" contents)
            (regexp-match? #rx"[.]?/s[.]rkt" contents))))))

(module+ test
  (run-tests GENERATED-CORE-SOURCE-DEPENDENCIES))
