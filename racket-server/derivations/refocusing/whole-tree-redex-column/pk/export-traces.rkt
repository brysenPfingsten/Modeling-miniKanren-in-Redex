#lang racket

(require racket/list
         racket/pretty
         redex/reduction-semantics
         (prefix-in corpus:
                    "../../whole-tree-pipeline-pilot/corpus.rkt")
         (prefix-in toy-l: "toy/labels.rkt")
         (prefix-in toy-s: "toy/source.rkt")
         (prefix-in toy-d: "toy/decomposition.rkt")
         (prefix-in toy-z: "toy/refocused.rkt")
         (prefix-in toy-zs: "toy/refocused-spec.rkt")
         (prefix-in toy-m: "toy/machine.rkt")
         (prefix-in toy-ms: "toy/machine-spec.rkt")
         (prefix-in toy-b: "toy/compressed.rkt")
         (prefix-in toy-bs: "toy/big-step-spec.rkt")
         (prefix-in toy-bd: "toy/big-step.rkt")
         (prefix-in toy-bl: "toy/big-step-language.rkt")
         (prefix-in mk-l: "mk/labels.rkt")
         (prefix-in mk-s: "mk/source.rkt")
         (prefix-in mk-d: "mk/decomposition.rkt")
         (prefix-in mk-z: "mk/refocused.rkt")
         (prefix-in mk-zs: "mk/refocused-spec.rkt")
         (prefix-in mk-m: "mk/machine.rkt")
         (prefix-in mk-ms: "mk/machine-spec.rkt")
         (prefix-in mk-b: "mk/compressed.rkt")
         (prefix-in mk-bs: "mk/big-step-spec.rkt")
         (prefix-in mk-bd: "mk/big-step.rkt")
         (prefix-in mk-bl: "mk/big-step-language.rkt"))

(provide render-traces)

(struct instance
  (source-successors
   decompose
   decomposition-successors
   decomposition-readback
   d->z
   initial-refocused
   refocused-successors
   z->m
   initial-machine
   machine-successors
   machine-readback
   initial-compressed
   compressed-successors
   compressed-readback
   big-step/spec
   big-step/direct
   big-step-readback)
  #:transparent)

(struct witness (title purpose root semantics) #:transparent)

(define (unique who results)
  (match results
    [(list result) result]
    [_ (error who "expected exactly one result, received ~e" results)]))

(define (trace-path current successors [remaining 1024]
                    [reverse-labels '()] [reverse-states (list current)])
  (match (successors current)
    ['() (values (reverse reverse-labels) (reverse reverse-states))]
    [(list (list label next))
     (unless (positive? remaining)
       (error 'trace-path "step cap reached at ~e" current))
     (trace-path next
                 successors
                 (sub1 remaining)
                 (cons label reverse-labels)
                 (cons next reverse-states))]
    [other
     (error 'trace-path "expected a deterministic path, received ~e" other)]))

(define (span-labels span)
  (match span
    [`(transition-span ,labels ...) labels]
    [_ (error 'span-labels "not a transition certificate: ~e" span)]))

(define (toy-source-successors frontier)
  (for/list
      ([named
        (in-list
         (apply-reduction-relation/tag-with-names
          toy-s:source-red/toy
          frontier))])
    (match-define (list name next) named)
    (list (term (toy-l:redex-name->label/toy ,(~a name)))
          next)))

(define (toy-initial-machine frontier)
  (term (toy-ms:initial-M/toy ,frontier)))

(define (toy-decompose frontier)
  (unique
   'toy-decompose
   (judgment-holds (toy-d:decompose/toy ,frontier D) D)))

(define (toy-decomposition-successors decomposition)
  (judgment-holds
   (toy-d:decomposed-step/direct/toy ,decomposition ell D_next)
   (ell D_next)))

(define (toy-decomposition-readback decomposition)
  (term (toy-d:plug-D/toy ,decomposition)))

(define (toy-d->z decomposition)
  (term (toy-z:D->Z/toy ,decomposition)))

(define (toy-initial-refocused frontier)
  (term (toy-zs:initial-Z/toy ,frontier)))

(define (toy-refocused-successors refocused)
  (judgment-holds
   (toy-z:refocused-step/direct/toy ,refocused ell Z_next)
   (ell Z_next)))

(define (toy-z->m refocused)
  (term (toy-m:encode-ZM/toy ,refocused)))

(define (toy-machine-successors machine)
  (judgment-holds
   (toy-m:machine-step/direct/toy ,machine ell M_next)
   (ell M_next)))

(define (toy-machine-readback machine)
  (term (toy-m:readback-M/toy ,machine)))

(define (toy-initial-compressed frontier)
  (unique
   'toy-initial-compressed
   (judgment-holds
    (toy-b:initial-compressed/direct/toy ,frontier B)
    B)))

(define (toy-compressed-successors compressed)
  (judgment-holds
   (toy-b:compressed-step/direct/toy ,compressed Span B_next)
   (Span B_next)))

(define (toy-compressed-readback compressed)
  (term (toy-b:compressed-readback/toy ,compressed)))

(define (toy-big-step/spec frontier)
  (judgment-holds
   (toy-bs:big-step/spec/toy ,frontier Spans O)
   (Spans O)))

(define (toy-big-step/direct frontier)
  (judgment-holds (toy-bd:big-step/direct/toy ,frontier O) O))

(define (toy-big-step-readback result)
  (term (toy-bl:big-step-readback/toy ,result)))

(define toy-instance
  (instance toy-source-successors
            toy-decompose
            toy-decomposition-successors
            toy-decomposition-readback
            toy-d->z
            toy-initial-refocused
            toy-refocused-successors
            toy-z->m
            toy-initial-machine
            toy-machine-successors
            toy-machine-readback
            toy-initial-compressed
            toy-compressed-successors
            toy-compressed-readback
            toy-big-step/spec
            toy-big-step/direct
            toy-big-step-readback))

(define (mk-source-successors frontier)
  (for/list
      ([named
        (in-list
         (apply-reduction-relation/tag-with-names
          mk-s:source-red/mk
          frontier))])
    (match-define (list name next) named)
    (list (term (mk-l:redex-name->label/mk ,(~a name)))
          next)))

(define (mk-initial-machine frontier)
  (term (mk-ms:initial-M/mk ,frontier)))

(define (mk-decompose frontier)
  (unique
   'mk-decompose
   (judgment-holds (mk-d:decompose/mk ,frontier D) D)))

(define (mk-decomposition-successors decomposition)
  (judgment-holds
   (mk-d:decomposed-step/direct/mk ,decomposition ell D_next)
   (ell D_next)))

(define (mk-decomposition-readback decomposition)
  (term (mk-d:plug-D/mk ,decomposition)))

(define (mk-d->z decomposition)
  (term (mk-z:D->Z/mk ,decomposition)))

(define (mk-initial-refocused frontier)
  (term (mk-zs:initial-Z/mk ,frontier)))

(define (mk-refocused-successors refocused)
  (judgment-holds
   (mk-z:refocused-step/direct/mk ,refocused ell Z_next)
   (ell Z_next)))

(define (mk-z->m refocused)
  (term (mk-m:encode-ZM/mk ,refocused)))

(define (mk-machine-successors machine)
  (judgment-holds
   (mk-m:machine-step/direct/mk ,machine ell M_next)
   (ell M_next)))

(define (mk-machine-readback machine)
  (term (mk-m:readback-M/mk ,machine)))

(define (mk-initial-compressed frontier)
  (unique
   'mk-initial-compressed
   (judgment-holds
    (mk-b:initial-compressed/direct/mk ,frontier B)
    B)))

(define (mk-compressed-successors compressed)
  (judgment-holds
   (mk-b:compressed-step/direct/mk ,compressed Span B_next)
   (Span B_next)))

(define (mk-compressed-readback compressed)
  (term (mk-b:compressed-readback/mk ,compressed)))

(define (mk-big-step/spec frontier)
  (judgment-holds
   (mk-bs:big-step/spec/mk ,frontier Spans O)
   (Spans O)))

(define (mk-big-step/direct frontier)
  (judgment-holds (mk-bd:big-step/direct/mk ,frontier O) O))

(define (mk-big-step-readback result)
  (term (mk-bl:big-step-readback/mk ,result)))

(define mk-instance
  (instance mk-source-successors
            mk-decompose
            mk-decomposition-successors
            mk-decomposition-readback
            mk-d->z
            mk-initial-refocused
            mk-refocused-successors
            mk-z->m
            mk-initial-machine
            mk-machine-successors
            mk-machine-readback
            mk-initial-compressed
            mk-compressed-successors
            mk-compressed-readback
            mk-big-step/spec
            mk-big-step/direct
            mk-big-step-readback))

(define mk-witness-goal
  '(fresh
    (x:q)
    (disj
     (conj
      (x:q =? (sym "cat") (label "bind"))
      (suspend
       (succeed (label "resume"))
       (label "delay"))
      (label "and"))
     (x:q != (sym "dog") (label "neq"))
     (label "or"))
    (label "query")))

(define witnesses
  (list
   (witness
    "Ktoy: nested fresh ownership"
    "The boundary fresh owns the whole frontier; the branch-local fresh is replicated across exactly its two choice descendants."
    corpus:nested-scope-witness-tree
    toy-instance)
   (witness
    "Ktoy: late hoisting"
    "A settled branch is distributed only after conjunction work has become available."
    corpus:late-hoist-witness-tree
    toy-instance)
   (witness
    "Ktoy: rail / flip-flop scheduling"
    "Two delayed branches exercise the rail turn and return rules."
    corpus:rail-turn-witness-tree
    toy-instance)
   (witness
    "Ktoy: right-active local fresh"
    "A delayed-left choice rotates right while its fresh scope remains branch-local, exposing the search-join-owned symmetric rule."
    corpus:right-active-fresh-witness-tree
    toy-instance)
   (witness
    "Kmk: unification, delay, and disequality"
    "The same control column runs over the c-free miniKanren kernel and retains its tagged atomic labels."
    (term (mk-s:initial-tree/mk ,mk-witness-goal))
    mk-instance)))

(define (salient-label? label)
  (match label
    [`(expose-frontier-fresh ,_) #t]
    [`(expose-choice-through-work-fresh ,_) #t]
    [`(late-distribute-settled ,_) #t]
    [`(late-distribute-right-settled ,_) #t]
    [`(rail-enter-right ,_) #t]
    [`(rail-return-left ,_) #t]
    [_ #f]))

(define (write-term value)
  (displayln "```racket")
  (parameterize ([pretty-print-columns 88])
    (pretty-write value))
  (displayln "```")
  (newline))

(define (write-numbered values)
  (for ([value (in-list values)] [index (in-naturals 1)])
    (printf "~a. `~s`\n" index value))
  (newline))

(define (write-salient-excerpts labels states)
  (define selected
    (for/list ([label (in-list labels)]
               [before (in-list states)]
               [after (in-list (rest states))]
               [index (in-naturals 1)]
               #:when (salient-label? label))
      (list index label before after)))
  (cond
    [(null? selected)
     (displayln "No fresh-exposure, late-hoist, or rail edge occurs in this trace.")
     (newline)]
    [else
     (for ([event (in-list selected)])
       (match-define (list index label before after) event)
       (printf "Edge ~a, `~s`:\n\n" index label)
       (displayln "Before:")
       (newline)
       (write-term before)
       (displayln "After:")
       (newline)
       (write-term after))]))

(define (write-witness item)
  (match-define (witness title purpose root semantics) item)
  (match-define
    (instance source-successors
              decompose
              decomposition-successors
              decomposition-readback
              d->z
              initial-refocused
              refocused-successors
              z->m
              initial-machine
              machine-successors
              machine-readback
              initial-compressed
              compressed-successors
              compressed-readback
              big-step/spec
              big-step/direct
              big-step-readback)
    semantics)

  (define-values (source-labels source-states)
    (trace-path root source-successors))
  (define decomposition-root (decompose root))
  (define-values (decomposition-labels decomposition-states)
    (trace-path decomposition-root decomposition-successors))
  (define refocused-root (initial-refocused root))
  (define-values (refocused-labels refocused-states)
    (trace-path refocused-root refocused-successors))
  (define machine-root (initial-machine root))
  (define-values (machine-labels machine-states)
    (trace-path machine-root machine-successors))
  (define compressed-root (initial-compressed root))
  (define-values (spans compressed-states)
    (trace-path compressed-root compressed-successors))
  (define spec-result (unique 'write-witness/spec (big-step/spec root)))
  (define direct-result (unique 'write-witness/direct (big-step/direct root)))
  (match-define (list certified-spans specification-result) spec-result)

  (unless (and (equal? source-labels decomposition-labels)
               (equal? source-labels refocused-labels)
               (equal? source-labels machine-labels))
    (error 'write-witness "R/D/Z/M labels disagree for ~a" title))
  (unless (for/and ([source (in-list source-states)]
                    [decomposition (in-list decomposition-states)])
            (equal? source (decomposition-readback decomposition)))
    (error 'write-witness "decomposition readback disagrees for ~a" title))
  (unless (for/and ([decomposition (in-list decomposition-states)]
                    [refocused (in-list refocused-states)])
            (equal? (d->z decomposition) refocused))
    (error 'write-witness "D/Z codec disagrees for ~a" title))
  (unless (for/and ([refocused (in-list refocused-states)]
                    [machine (in-list machine-states)])
            (equal? (z->m refocused) machine))
    (error 'write-witness "Z/M codec disagrees for ~a" title))
  (unless (equal? machine-labels (append-map span-labels spans))
    (error 'write-witness "compressed spans do not partition exact trace for ~a" title))
  (unless (equal? certified-spans spans)
    (error 'write-witness "big-step certificate differs from compressed path for ~a" title))
  (unless (equal? specification-result direct-result)
    (error 'write-witness "specification and promoted result disagree for ~a" title))

  (define source-final (last source-states))
  (define machine-final (last machine-states))
  (define compressed-final (last compressed-states))
  (define readbacks
    (list source-final
          (machine-readback machine-final)
          (compressed-readback compressed-final)
          (big-step-readback direct-result)))
  (unless (andmap (lambda (readback)
                    (equal? (first readbacks) readback))
                  (rest readbacks))
    (error 'write-witness "terminal readbacks disagree for ~a: ~e" title readbacks))

  (printf "## ~a\n\n" title)
  (displayln purpose)
  (newline)
  (displayln "### Source boundary")
  (newline)
  (displayln "Initial whole frontier:")
  (newline)
  (write-term root)
  (printf "The source has ~a exact edges and terminates at:\n\n"
          (length source-labels))
  (write-term source-final)

  (displayln "### Decomposition, refocusing, and exact-machine alignment")
  (newline)
  (printf "The independently stated R, direct D, direct Z, and direct M relations agree on all ~a labels. At every state, `plug-D(D) = R`, `D->Z(D) = Z`, and `encode-ZM(Z) = M`:\n\n"
          (length source-labels))
  (write-numbered source-labels)
  (displayln "Initial and terminal decomposition states:")
  (newline)
  (write-term decomposition-root)
  (write-term (last decomposition-states))
  (displayln "Initial and terminal refocused states:")
  (newline)
  (write-term refocused-root)
  (write-term (last refocused-states))
  (displayln "Exact-machine initial state:")
  (newline)
  (write-term machine-root)
  (displayln "Exact-machine terminal state:")
  (newline)
  (write-term machine-final)

  (displayln "### Salient source edges")
  (newline)
  (write-salient-excerpts source-labels source-states)

  (displayln "### Compressed boundary")
  (newline)
  (printf "The direct compressed path has ~a nonempty certified macro edges:\n\n"
          (length spans))
  (write-numbered spans)
  (displayln "Compressed initial state:")
  (newline)
  (write-term compressed-root)
  (displayln "Compressed terminal state:")
  (newline)
  (write-term compressed-final)

  (displayln "### Big-step boundary")
  (newline)
  (displayln "The closure specification's ordered certificate is exactly the compressed span list above. The independently promoted judgment returns:")
  (newline)
  (write-term direct-result)
  (displayln "All four terminal readbacks (source, exact machine, compressed machine, and promoted result) are identical:")
  (newline)
  (write-term source-final))

(define (render-traces)
  (regexp-replace
   #rx"\n$"
   (with-output-to-string
    (lambda ()
      (displayln "# Executable representative traces")
      (newline)
      (displayln "This file is deterministically rendered by `racket export-traces.rkt`. The exporter aborts unless, for every witness below:")
      (newline)
      (displayln "- the R, direct D, direct Z, and direct M label sequences are equal;")
      (displayln "- every aligned D, Z, and M state satisfies the explicit readback/codec equations;")
      (displayln "- the nonempty compressed spans partition that exact sequence;")
      (displayln "- the closure certificate equals the direct compressed path;")
      (displayln "- the closure specification and independently promoted big-step judgment return the same result; and")
      (displayln "- source, exact, compressed, and promoted terminal readbacks agree.")
      (newline)
      (displayln "These are executable traces of the selected witnesses, not universal proofs.")
      (newline)
      (for ([item (in-list witnesses)])
        (write-witness item))))
   ""))

(module+ main
  (display (render-traces)))
