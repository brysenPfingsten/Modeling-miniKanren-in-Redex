#lang racket

(require racket/set
         racket/list
         "transpiler.rkt"
         "syntax-checking.rkt"
         "model-registry.rkt")

(provide ANALYSIS-VERSION
         REQ-CORE
         REQ-RELCALL
         REQ-DISJUNCTION
         REQ-FRESH
         requirement->capability
         ast->requirements
         analyze-source-capabilities
         incompatible-reasons
         compatible-model-ids
         incompatible-model-ids)

(define ANALYSIS-VERSION "v1")

(define REQ-CORE "req/core")
(define REQ-RELCALL "req/relcall")
(define REQ-DISJUNCTION "req/disjunction")
(define REQ-FRESH "req/fresh")

(define (struct-tag v)
  (and (struct? v) (vector-ref (struct->vector v) 0)))

(define (tag=? v tag-sym)
  (eq? (struct-tag v) tag-sym))

(define (struct-field v idx [default #f])
  (define vec (and (struct? v) (struct->vector v)))
  (if (and vec (< idx (vector-length vec)))
      (vector-ref vec idx)
      default))

(define (read-all port)
  (let ([expr (read port)])
    (if (eof-object? expr)
        '()
        (cons expr (read-all port)))))

(define (requirement->capability req)
  (cond
    [(equal? req REQ-CORE) "cap/core"]
    [(equal? req REQ-RELCALL) "cap/relcall"]
    [(equal? req REQ-DISJUNCTION) "cap/disjunction"]
    [(equal? req REQ-FRESH) "cap/fresh"]
    [else #f]))

(define (goal->requirements g)
  (cond
    [(tag=? g 'struct:fresh)
     (set-add (goal->requirements (struct-field g 2)) REQ-FRESH)]
    [(tag=? g 'struct:conde)
     (for/fold ([acc (set REQ-DISJUNCTION)])
               ([clause (in-list (struct-field g 1 '()))])
       (set-union acc (goal->requirements clause)))]
    [(tag=? g 'struct:disj)
     (set-union (set REQ-DISJUNCTION)
                (goal->requirements (struct-field g 1))
                (goal->requirements (struct-field g 2)))]
    [(tag=? g 'struct:conj)
     (set-union (goal->requirements (struct-field g 1))
                (goal->requirements (struct-field g 2)))]
    [(tag=? g 'struct:relcall)
     (set REQ-RELCALL)]
    [else (set)]))

(define (ast->requirements ast)
  (define reqs (set REQ-CORE))
  (define reqs-with-rels
    (if (tag=? ast 'struct:prog)
        (for/fold ([acc reqs])
                  ([rel (in-list (struct-field ast 1 '()))])
          (if (tag=? rel 'struct:defrel)
              (set-union acc (goal->requirements (struct-field rel 3)))
              acc))
        reqs))
  (define reqs*
    (if (tag=? ast 'struct:prog)
        (let ([query (struct-field ast 2)])
          (if (tag=? query 'struct:run)
              (set-union reqs-with-rels
                         (goal->requirements (struct-field query 3)))
              reqs-with-rels))
        reqs-with-rels))
  (sort (set->list reqs*) string<?))

(define (analyze-source-capabilities source)
  (check-syntax-capture-error source)
  (define sexprs (read-all (open-input-string source)))
  (define ast (parse-prog->ast sexprs))
  (hasheq 'validSyntax #t
          'requirements (ast->requirements ast)
          'analysisVersion ANALYSIS-VERSION))

(define (missing-capabilities requirements capabilities)
  (define caps (list->set capabilities))
  (for/list ([req (in-list requirements)]
             #:do [(define cap (requirement->capability req))]
             #:when (and cap (not (set-member? caps cap))))
    (list req cap)))

(define (incompatible-reasons requirements capabilities)
  (for/list ([entry (in-list (missing-capabilities requirements capabilities))])
    (match-define (list req cap) entry)
    (format "missing ~a (required by ~a)" cap req)))

(define (compatible-model-ids requirements specs)
  (for/list ([spec (in-list specs)]
             #:when (null? (incompatible-reasons requirements
                                                 (model-spec-capabilities spec))))
    (model-spec-id spec)))

(define (incompatible-model-ids requirements specs)
  (for/list ([spec (in-list specs)]
             #:when (not (null? (incompatible-reasons requirements
                                                      (model-spec-capabilities spec)))))
    (model-spec-id spec)))
