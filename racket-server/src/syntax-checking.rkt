#lang racket

(require redex/reduction-semantics
         racket/port
         racket/sandbox)
(require "judgment-forms.rkt"
         "core-judgment-forms.rkt"
         (only-in "core-definitions.rkt" Core))
(provide check-well-formed
         legacy-well-formed?
         canonical-core-shape?
         canonical-well-formed?
         check-canonical-or-legacy-well-formed
         check-syntax-capture-error)

;; Prog -> String
;; Purpose: Checks if the given program satisfies the closed-program? judgment.
;; Returns: Empty string if well-formed, else error message.
(define (legacy-well-formed? model-prog)
  (judgment-holds (closed-program? ,model-prog)))

(define (check-well-formed model-prog)
  (if (legacy-well-formed? model-prog)
      ""
      (error "Program is not well formed!")))

;; Canonical-config -> boolean
;; Purpose: True when config is in the core judgment fragment shape.
(define (canonical-core-shape? canonical-config)
  (and (redex-match? Core config canonical-config)
       (judgment-holds (core-shape? ,canonical-config))))

;; Canonical-config -> boolean
;; Purpose: True when canonical config satisfies core wf-config? judgment.
(define (canonical-well-formed? canonical-config)
  (and (redex-match? Core config canonical-config)
       (judgment-holds (wf-config? ,canonical-config))))

;; Legacy-program Canonical-config -> String or Error
;; Purpose: Prefer canonical core wf gate, fallback to legacy gate for
;; non-core-shape programs during transition.
(define (check-canonical-or-legacy-well-formed legacy-prog canonical-config)
  (cond
    [(canonical-core-shape? canonical-config)
     (if (canonical-well-formed? canonical-config)
         ""
         (error "Program failed canonical wf-config? check."))]
    [(legacy-well-formed? legacy-prog)
     ""]
    [else
     (error "Program is not well formed!")]))


;; read-all: port -> ListOf sexpression
;; Purpose: To read the string program into sexpressions
(define (read-all port)
  (let ([expr (read port)])
    (if (eof-object? expr)
        '()  ;; Stop when EOF is reached
        (cons expr (read-all port)))))


;; String -> String or Error
;; Purpose: Uses syntax-spec to throw static errors in the given program.
(define (check-syntax-capture-error program-str)
    (parameterize ([current-namespace (make-base-namespace)])
      (expand (datum->syntax #f
                             `(module syntax-checker racket/base
                                (require hosted-minikanren)
                                ,@(read-all (open-input-string program-str)))))))
