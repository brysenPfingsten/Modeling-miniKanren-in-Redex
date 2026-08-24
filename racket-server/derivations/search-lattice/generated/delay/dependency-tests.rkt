#lang racket

(require racket/runtime-path
         rackunit
         rackunit/text-ui)

(provide GENERATED-DELAY-DEPENDENCY-TESTS)

(define-runtime-path framework-file "../../framework/delay-schema.rkt")
(define-runtime-path stage-framework-file
  "../../framework/core-stage-renderers.rkt")
(define-runtime-path source-s-file "source/s.rkt")
(define-runtime-path source-e-file "source/e.rkt")
(define-runtime-path source-n-file "source/n.rkt")
(define-runtime-path source-vertical-file "source/vertical.rkt")
(define-runtime-path stage-s-file "stages/s.rkt")
(define-runtime-path stage-e-file "stages/e.rkt")
(define-runtime-path stage-n-file "stages/n.rkt")
(define-runtime-path stage-vertical-file "stages/vertical.rkt")
(define-runtime-path corpus-file "corpus.rkt")
(define-runtime-path horizontal-file "horizontal-tests.rkt")
(define-runtime-path cube-file "cube-tests.rkt")
(define-runtime-path diagnostic-file "transport-diagnostics-tests.rkt")

(define source-row-files (list source-s-file source-e-file source-n-file))
(define stage-row-files (list stage-s-file stage-e-file stage-n-file))
(define public-implementation-files
  (append
   (list framework-file
         stage-framework-file
         source-vertical-file
         stage-vertical-file)
   source-row-files
   stage-row-files))

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

(define GENERATED-DELAY-DEPENDENCY-TESTS
  (test-suite
   "generated Delay dependency and architecture inventory"

   (test-case "selected public modules never expose the frozen environment route"
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

   (test-case "no selected adapter fabricates an environment or scheduler"
     (for ([path (in-list public-implementation-files)])
       (define contents (file->string path))
       (for ([forbidden
              (in-list
               '("fake environment"
                 "materialize-environment"
                 "environment-adapter"
                 "round-robin"
                 "scheduler"
                 "schedule-next"
                 "AllocateEvent"))])
         (check-false
          (regexp-match? (regexp (regexp-quote forbidden)) contents)
          (format "forbidden adapter/scheduler token ~a in ~a"
                  forbidden
                  path)))))

   (test-case "the Delay schema remains representation neutral"
     (define contents (file->string framework-file))
     (for ([concrete (in-list '("(Owner " "(Owners" "(Support" "u:"))])
       (check-false
        (regexp-match? (regexp (regexp-quote concrete)) contents)
        (format "Delay schema contains concrete representation case ~a"
                concrete)))
     (for ([required
            (in-list
             '("define-delay-representation-view"
               "define-generated-delay-source"
               "define-generated-delay-stage-extension"
               "#:visit"
               "#:visit-delay"
               "#:visit-extension"
               "suspend-goal"
               "bubble-delay-through-conj"
               "force-delay"))])
       (check-true
        (regexp-match? (regexp (regexp-quote required)) contents)
        (format "Delay schema lacks required neutral facility ~a" required))))

   (test-case "each source row consumes the full direct representation view"
     (for ([entry
            (in-list
             (list
              (list source-s-file "delay-s-representation-view"
                    "generated-delay-s-source")
              (list source-e-file "delay-e-representation-view"
                    "generated-delay-e-source")
              (list source-n-file "delay-n-representation-view"
                    "generated-delay-n-source")))])
       (match-define (list path view source) entry)
       (define contents (file->string path))
       (check-equal?
        (match-count #px"[(]define-delay-representation-view\\s" contents)
        1)
       (check-equal?
        (match-count #px"[(]define-generated-delay-source\\s" contents)
        1)
       (check-true (regexp-match? (regexp (regexp-quote view)) contents))
       (check-true (regexp-match? (regexp (regexp-quote source)) contents))
       (for ([hook
              (in-list
               '("#:export"
                 "#:rebuild"
                 "#:focus-export"
                 "#:focus-rebuild"
                 "#:root-focus-export"
                 "#:root-focus-rebuild"
                 "#:failure-focus-export"
                 "#:failure-focus-rebuild"
                 "#:terminal-export"
                 "#:terminal-rebuild"))])
         (check-true
          (regexp-match? (regexp (regexp-quote hook)) contents)
          (format "row ~a lacks joint view hook ~a" path hook)))))

   (test-case "each stage row extends its own direct source and core row"
     (for ([entry
            (in-list
             (list
              (list stage-s-file "generated-delay-s-source"
                    "core:core/staged-row/S" "delay/staged-row/S")
              (list stage-e-file "generated-delay-e-source"
                    "core:core/staged-row/E" "delay/staged-row/E")
              (list stage-n-file "generated-delay-n-source"
                    "core:core/staged-row/N" "delay/staged-row/N")))])
       (match-define (list path source base row) entry)
       (define contents (file->string path))
       (check-equal?
        (match-count #px"[(]define-generated-delay-stage-extension\\s"
                     contents)
        1)
       (check-equal?
        (match-count #px"[(]apply-selected-stage-extension\\s" contents)
        1)
       (for ([required (in-list (list source base row))])
         (check-true
          (regexp-match? (regexp (regexp-quote required)) contents)))))

   (test-case "direct S-to-N maps do not route through E"
     (define source-contents (file->string source-vertical-file))
     (define source-direct
       (source-slice
        source-contents
        "(define (Q-SN/R/delay frontier)"
        "(define (Q-SN/R-composition/delay? frontier)"))
     (check-false (regexp-match? #rx"Q-SE" source-direct))
     (check-false (regexp-match? #rx"Q-EN" source-direct))

     (define stage-contents (file->string stage-vertical-file))
     (define stage-direct
       (source-slice
        stage-contents
        ";; Direct S-to-N maps use only the S and N views/rows."
        "(define (Q-SN/D-composition/stages/delay?"))
     (check-false (regexp-match? #rx"Q-SE" stage-direct))
     (check-false (regexp-match? #rx"Q-EN" stage-direct))
     (check-false (regexp-match? #rx"e:delay/staged-row" stage-direct)))

   (test-case "every primary phase owns a direct generated transition surface"
     (define contents (file->string framework-file))
     (for ([artifact
            (in-list
             '("D-step"
               "Z-refocus-frontier"
               "Z-step"
               "M-refocus-frontier"
               "M-step"
               "B-refocus-frontier"
               "B-singleton"
               "B-step"
               "Big-dispatch-one"
               "Big-control-one"
               "Big-refocus-frontier"
               "Big-evaluate"
               "Big-promote"))])
       (check-true
        (regexp-match? (regexp (regexp-quote artifact)) contents)
        (format "missing direct artifact ~a" artifact)))
     (define primary-M
       (source-slice contents
                     "(M-artifacts"
                     "#:diagnostic-parameters"))
     (define primary-Big
       (source-slice contents
                     "(Big-artifacts"
                     "#:diagnostic-parameters"))
     (for ([primary (in-list (list primary-M primary-Big))]
           [phase (in-list '(M Big))])
       (for ([forbidden (in-list '("decode" "readback" "spec"))])
         (check-false
          (regexp-match? (regexp (regexp-quote forbidden)) primary)
          (format "primary ~a route contains diagnostic token ~a"
                  phase forbidden)))))

   (test-case "codec and readback paths remain secondary test diagnostics"
     (define horizontal (file->string horizontal-file))
     (define cube (file->string cube-file))
     (define diagnostics (file->string diagnostic-file))
     (for ([primary (in-list (list horizontal cube))])
       (for ([forbidden
              (in-list '("diagnostic-decode"
                         "diagnostic-readback"
                         "diagnostic-Big-evaluate"))])
         (check-false
          (regexp-match? (regexp (regexp-quote forbidden)) primary))))
     (for ([required
            (in-list
             '("diagnostic-D->Z"
               "diagnostic-Z->D"
               "diagnostic-readback-Z"
               "diagnostic-encode-ZM"
               "diagnostic-decode-MZ"
               "diagnostic-readback-M"
               "diagnostic-ZM-corresponds"
               "diagnostic-ZM-square"
               "diagnostic-encode-MB"
               "diagnostic-decode-BM"
               "diagnostic-readback-B"
               "diagnostic-MB-corresponds"
               "diagnostic-replay-M"
               "diagnostic-MB-square"
               "diagnostic-readback-Big"
               "diagnostic-B-Big-unfold"
               "diagnostic-B-Big-closure"
               "diagnostic-B-Big-root"))])
       (check-true
        (regexp-match? (regexp (regexp-quote required)) diagnostics))))

   (test-case "proof and corpus evidence never deduplicates matrix coordinates"
     (for ([path (in-list (list horizontal-file cube-file corpus-file))])
       (define contents (file->string path))
       (check-false
        (regexp-match? #rx"remove-duplicates" contents)
        (format "evidence deduplicates raw proofs in ~a" path)))
     (define corpus (file->string corpus-file))
     (for ([forbidden
            (in-list '("Q-SE" "Q-EN" "Q-SN" "codec" "readback"))])
       (check-false
        (regexp-match? (regexp (regexp-quote forbidden)) corpus)
        (format "corpus constructs a coordinate through ~a" forbidden))))))

(module+ test
  (run-tests GENERATED-DELAY-DEPENDENCY-TESTS))
