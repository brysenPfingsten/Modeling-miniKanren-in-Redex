#lang racket

(require redex/reduction-semantics "../../shared/maps.rkt")

(provide (struct-out BigCertificate) derivation->certificate certify/raw
         QBig-SE QBig-EN QBig-SN)

;; A finite natural derivation retains its operation, exact feature/row,
;; inherited S prefix, native query/result, ordered source labels, and every
;; recursive premise. Rule-display names are omitted: S and ownerless rule
;; names differ, while the operation/query/premise tree determines the rule.
;; This is not merely a final-value wrapper or a source execution trace.
(struct BigCertificate (kind coordinate prefix input output labels premises) #:transparent)

(define (derivation->certificate proof)
  (match-define (cons name arguments) (derivation-term proof))
  (match-define
    (list _ kind-text row-text feature-text)
    (regexp-match #rx"^(program|search|merge|bind|render|commit|advance|collect|observe)-big/([sen])(-core|-delay|-disjunction|-rel)?$"
                  (symbol->string name)))
  (define kind (string->symbol kind-text))
  (define coordinate (string->symbol (string-append row-text (or feature-text ""))))
  (define row-s? (equal? row-text "s"))
  (define program? (eq? kind 'program))
  (define full-premise? (and (equal? feature-text "-rel") (not program?)))
  (define definitions (and full-premise? (first arguments)))
  (define row-arguments (if full-premise? (rest arguments) arguments))
  (define prefix (if (and row-s? (not program?)) (first row-arguments) '()))
  (define local-arguments (if (and row-s? (not program?)) (rest row-arguments) row-arguments))
  (match-define (list output labels) (take-right local-arguments 2))
  (define inputs (drop-right local-arguments 2))
  (define input
    (match* (kind inputs)
      [('search (list computation)) computation]
      [('program (list computation)) computation]
      [('observe (list computation)) computation]
      [('render (list search)) `(render ,search)]
      [('commit (list search)) `(commit ,search)]
      [('advance (list frontier)) `(advance ,frontier)]
      [('collect (list frontier)) `(collect ,frontier)]
      [('merge _) `(mplus ,@inputs)]
      [('bind _) `(bind ,@inputs)]))
  ;; Full premises retain their own Γ, rather than relying on the certificate
  ;; root or a closure to recover recursive-call meaning. The shared vertical
  ;; maps preserve the lexical definition syntax and map each native body.
  (BigCertificate kind coordinate prefix
                  (if full-premise? `(program ,definitions ,input) input)
                  (if full-premise? `(program ,definitions ,output) output) labels
                  (map derivation->certificate (derivation-subs proof))))

(define (certify/raw raw computation)
  (match (raw computation)
    [(list proof) (derivation->certificate proof)]
    [proofs (error 'certify/raw "expected exactly one raw Big proof, got ~a" (length proofs))]))

(define (coordinate-map coordinate source target)
  (define text (symbol->string coordinate))
  (unless (and (positive? (string-length text)) (char=? (string-ref text 0) source))
    (raise-argument-error 'QBig "certificate in the source row" coordinate))
  (string->symbol (string-append (string target) (substring text 1))))

;; Each clause maps the native query and result at THIS premise's support.
;; S support has become explicit E state fields, so the target prefix is ().
;; Every child is mapped recursively; labels and premise order are retained.
(define (QBig-SE certificate)
  (match-define (BigCertificate kind coordinate prefix input output labels premises) certificate)
  (BigCertificate kind (coordinate-map coordinate #\s #\e) '()
                  (Q-SE input prefix) (Q-SE output prefix) labels
                  (map QBig-SE premises)))

(define (QBig-EN certificate)
  (match-define (BigCertificate kind coordinate prefix input output labels premises) certificate)
  (unless (null? prefix) (raise-argument-error 'QBig-EN "ownerless Big certificate" certificate))
  (BigCertificate kind (coordinate-map coordinate #\e #\n) '()
                  (Q-EN input) (Q-EN output) labels
                  (map QBig-EN premises)))

;; Direct S -> N is independently defined with Q-SN at every premise; this
;; function does not invoke QBig-SE/QBig-EN or construct an intermediate E row.
(define (QBig-SN certificate)
  (match-define (BigCertificate kind coordinate prefix input output labels premises) certificate)
  (BigCertificate kind (coordinate-map coordinate #\s #\n) '()
                  (Q-SN input prefix) (Q-SN output prefix) labels
                  (map QBig-SN premises)))
