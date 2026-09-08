#lang racket

(provide (struct-out Stage) (struct-out Frame)
         (struct-out Descend) (struct-out Local) (struct-out Value)
         (struct-out D) (struct-out DFinal) (struct-out Z)
         (struct-out M) (struct-out K) (struct-out BRun) (struct-out BFinal)
         (struct-out Span)
         plug-frame plug-frames frame-support continuation-support frame-environment
         decompose readback-D d-step initial-Z z-step readback-Z
         encode-ZM decode-MZ initial-M m-step m-admin? m-final? readback-M
         initial-B b-step decode-BM readback-B b-step/spec replay-span
         compression-square? semantic-labels
         d-trace z-trace m-trace b-trace run-D run-Z run-M run-B)

;; A row module supplies only its native syntax view, local
;; source contraction and owner-prefix operation. No state is converted to a
;; preferred row and no stage transition calls the previous stage transition.
;; The shared construction follows the preserved marked framework's
;; plug/contract/redecompose, retained refocus, reification, direct/spec span
;; split. Its strict constructor views and rules are newly derived.
(struct Stage (name contract view extend-support) #:transparent)

;; before/after are the exact constructor fields surrounding one hole.
;; Owners contains only the ancestor constructor's local provenance, never
;; its head Answer's or sibling's provenance. Stacks are innermost first.
(struct Frame (kind before after owners) #:transparent)
(struct Descend (control frame) #:transparent)
(struct Local () #:transparent)
(struct Value () #:transparent)
(struct D (redex frames) #:transparent)
(struct DFinal (value) #:transparent)
(struct Z (control frames) #:transparent)
(struct M (control continuation) #:transparent)
(struct K (frame rest) #:transparent)
(struct BRun (control continuation) #:transparent)
(struct BFinal (value) #:transparent)
(struct Span (labels) #:transparent
  #:guard
  (lambda (labels name)
    (unless (and (pair? labels) (list? labels) (andmap string? labels)
                 (not (equal? (first labels) "admin"))
                 (andmap (lambda (label) (equal? label "admin")) (rest labels)))
      (raise-argument-error name "one source label followed by admin labels" labels))
    labels))

(define (plug-frame control frame)
  (append (Frame-before frame) (list control) (Frame-after frame)))

(define (plug-frames control frames)
  (match frames
    ['() control]
    [(cons frame rest) (plug-frames (plug-frame control frame) rest)]))

;; The full-language extension retains its relation environment as ordinary
;; program-frame data. Empty Γ is distinct from an absent program frame.
(define (frame-environment frames)
  (match frames
    ['() #f]
    [(cons (Frame 'program (list 'program definitions) '() #f) _) definitions]
    [(cons _ rest) (frame-environment rest)]))

(define (contract/frames stage control frames)
  (define support (frame-support stage frames))
  (define definitions (frame-environment frames))
  (if definitions
      ((Stage-contract stage) control support definitions)
      ((Stage-contract stage) control support)))

(define (frame-support stage frames)
  (match frames
    ['() '()]
    [(cons frame rest)
     ((Stage-extend-support stage) (frame-support stage rest) (Frame-owners frame))]))

(define (continuation-support stage continuation)
  (match continuation
    ['halt '()]
    [(K frame rest)
     ((Stage-extend-support stage) (continuation-support stage rest) (Frame-owners frame))]))

;; D's traversal is repeated from the whole reconstructed source after every
;; contraction. Only shape inspection happens during traversal.
(define (decompose stage computation [frames '()])
  (match ((Stage-view stage) computation)
    [(Local) (D computation frames)]
    [(Descend child frame) (decompose stage child (cons frame frames))]
    [(Value)
     (match frames
       ['() (DFinal computation)]
       [(cons (Frame 'merge-left before (list right) owners) rest)
        (decompose stage right
                   (cons (Frame 'merge-right (append before (list computation)) '() owners)
                         rest))]
       [(cons frame rest) (decompose stage (plug-frame computation frame) rest)])]))

(define (readback-D configuration)
  (match configuration
    [(DFinal value) value]
    [(D redex frames) (plug-frames redex frames)]))

(define (completed-value? stage value)
  (Value? ((Stage-view stage) value)))

(define (d-step stage configuration)
  (match configuration
    [(DFinal value)
     (unless (completed-value? stage value)
       (raise-argument-error 'd-step "DFinal containing an admitted value" configuration))
     #f]
    [(D redex frames)
     (match (contract/frames stage redex frames)
       [(list label next) (list label (decompose stage (plug-frames next frames)))]
       [#f (error 'd-step "stuck ~a decomposition: ~e" (Stage-name stage) configuration)])]))

;; Initial traversal is administrative. All machine stages start at the same
;; canonical first redex, keeping their exact finite traces comparable.
(define (initial-Z stage computation)
  (match (decompose stage computation)
    [(D redex frames) (Z redex frames)]
    [(DFinal value) (Z value '())]))

(define (readback-Z configuration)
  (match-define (Z control frames) configuration)
  (plug-frames control frames))

(define (z-step stage configuration)
  (match-define (Z control frames) configuration)
  (match ((Stage-view stage) control)
    [(Local)
     (match (contract/frames stage control frames)
       [(list label next) (list label (Z next frames))]
       [#f (error 'z-step "stuck ~a local control: ~e" (Stage-name stage) control)])]
    [(Descend child frame) (list "admin" (Z child (cons frame frames)))]
    [(Value)
     (match frames
       ['() #f]
       [(cons (Frame 'merge-left before (list right) owners) rest)
        (list "admin"
              (Z right (cons (Frame 'merge-right (append before (list control)) '() owners)
                             rest)))]
       [(cons frame rest) (list "admin" (Z (plug-frame control frame) rest))])]))

(define (encode-frames frames)
  (match frames ['() 'halt] [(cons frame rest) (K frame (encode-frames rest))]))

(define (decode-frames continuation)
  (match continuation ['halt '()] [(K frame rest) (cons frame (decode-frames rest))]))

(define (encode-ZM configuration)
  (match-define (Z control frames) configuration)
  (M control (encode-frames frames)))

(define (decode-MZ configuration)
  (match-define (M control continuation) configuration)
  (Z control (decode-frames continuation)))

(define (initial-M stage computation) (encode-ZM (initial-Z stage computation)))

(define (readback/continuation control continuation)
  (match continuation
    ['halt control]
    [(K frame rest) (readback/continuation (plug-frame control frame) rest)]))

(define (readback-M configuration)
  (match-define (M control continuation) configuration)
  (readback/continuation control continuation))

(define (m-final? stage configuration)
  (match configuration
    [(M control 'halt) (Value? ((Stage-view stage) control))]
    [_ #f]))

(define (m-admin? stage configuration)
  (match-define (M control continuation) configuration)
  (match ((Stage-view stage) control)
    [(Local) #f]
    [(Descend _ _) #t]
    [(Value) (not (eq? continuation 'halt))]))

;; Independently stated M rules in a nested continuation representation. The
;; shared contract procedure is the source's local rule boundary, just as
;; contract/redex was in the original marked machine derivation. It does not
;; execute D, Z, or any source context closure.
(define (m-step stage configuration)
  (match-define (M control continuation) configuration)
  (match ((Stage-view stage) control)
    [(Descend child frame) (list "admin" (M child (K frame continuation)))]
    [(Value)
     (match continuation
       ['halt #f]
       [(K (Frame 'merge-left before (list right) owners) rest)
        (list "admin"
              (M right (K (Frame 'merge-right (append before (list control)) '() owners)
                          rest)))]
       [(K frame rest) (list "admin" (M (plug-frame control frame) rest))])]
    [(Local)
     (match (contract/frames stage control (decode-frames continuation))
       [(list label next) (list label (M next continuation))]
       [#f (error 'm-step "stuck ~a machine: ~e" (Stage-name stage) configuration)])]))

(define (initial-B stage computation)
  (match (decompose stage computation)
    [(DFinal value) (BFinal value)]
    [(D redex frames) (BRun redex (encode-frames frames))]))

(define (decode-BM configuration)
  (match configuration
    [(BFinal value) (M value 'halt)]
    [(BRun control continuation) (M control continuation)]))

(define (readback-B configuration) (readback-M (decode-BM configuration)))

;; Symbolically specialized residual dispatcher, independent of M/Z
;; transitions. Recursion is finite structural administration; it never
;; contracts another source redex or forces a Delay.
(define (residual stage control continuation reversed)
  (match ((Stage-view stage) control)
    [(Local) (list (Span (reverse reversed)) (BRun control continuation))]
    [(Descend child frame)
     (residual stage child (K frame continuation) (cons "admin" reversed))]
    [(Value)
     (match continuation
       ['halt (list (Span (reverse reversed)) (BFinal control))]
       [(K (Frame 'merge-left before (list right) owners) rest)
        (residual stage right
                  (K (Frame 'merge-right (append before (list control)) '() owners) rest)
                  (cons "admin" reversed))]
       [(K frame rest)
        (residual stage (plug-frame control frame) rest (cons "admin" reversed))])]))

(define (b-step stage configuration)
  (match configuration
    [(BFinal value)
     (unless (completed-value? stage value)
       (raise-argument-error 'b-step "BFinal containing an admitted value" configuration))
     #f]
    [(BRun control continuation)
     (unless (Local? ((Stage-view stage) control))
       (error 'b-step "not a canonical ~a residual: ~e" (Stage-name stage) configuration))
     (match (contract/frames stage control (decode-frames continuation))
       [(list label next) (residual stage next continuation (list label))]
       [#f (error 'b-step "stuck ~a residual: ~e" (Stage-name stage) configuration)])]))

(define (semantic-labels span)
  (filter (lambda (label) (not (equal? label "admin"))) (Span-labels span)))

(define (replay-span stage configuration span)
  (define (replay current labels)
    (match labels
      ['() current]
      [(cons expected rest)
       (match (m-step stage current)
         [(list label next) (and (equal? label expected) (replay next rest))]
         [#f #f])]))
  (replay configuration (Span-labels span)))

;; Independent specification and exact, label-sensitive finite-path replay.
(define (b-step/spec stage configuration)
  (define (administration current reversed)
    (cond
      [(m-admin? stage current)
       (match-define (list label next) (m-step stage current))
       (unless (equal? label "admin") (error 'b-step/spec "admin classifier mismatch"))
       (administration next (cons label reversed))]
      [else (list (Span (reverse reversed)) current)]))
  (match (m-step stage (decode-BM configuration))
    [#f #f]
    [(list "admin" _) (error 'b-step/spec "noncanonical residual")]
    [(list label next) (administration next (list label))]))

(define (compression-square? stage configuration)
  (match* ((b-step stage configuration) (b-step/spec stage configuration))
    [(#f #f) #t]
    [((list span next) (list expected endpoint))
     (and (equal? span expected)
          (equal? (decode-BM next) endpoint)
          (equal? (replay-span stage (decode-BM configuration) span) endpoint))]
    [(_ _) #f]))

(define (trace/steps who step final? configuration fuel [reversed '()])
  (cond
    [(final? configuration) (reverse reversed)]
    [(zero? fuel) (error who "strict matrix fuel exhausted")]
    [else
     (match (step configuration)
       [(and edge (list _ next))
        (trace/steps who step final? next (sub1 fuel) (cons edge reversed))]
       [#f (error who "unexpected nonfinal stuck state: ~e" configuration)])]))

(define (valid-fuel who fuel)
  (unless (exact-nonnegative-integer? fuel)
    (raise-argument-error who "exact-nonnegative-integer?" fuel)))

(define (d-trace stage configuration #:fuel [fuel 100000])
  (valid-fuel 'd-trace fuel)
  (trace/steps 'd-trace (lambda (current) (d-step stage current))
               (lambda (current)
                 (and (DFinal? current) (completed-value? stage (DFinal-value current))))
               configuration fuel))

(define (z-trace stage configuration #:fuel [fuel 100000])
  (valid-fuel 'z-trace fuel)
  (trace/steps 'z-trace (lambda (current) (z-step stage current))
               (lambda (current)
                 (match current [(Z control '()) (Value? ((Stage-view stage) control))] [_ #f]))
               configuration fuel))

(define (m-trace stage configuration #:fuel [fuel 100000])
  (valid-fuel 'm-trace fuel)
  (trace/steps 'm-trace (lambda (current) (m-step stage current))
               (lambda (current) (m-final? stage current)) configuration fuel))

(define (b-trace stage configuration #:fuel [fuel 100000])
  (valid-fuel 'b-trace fuel)
  (trace/steps 'b-trace (lambda (current) (b-step stage current))
               (lambda (current)
                 (and (BFinal? current) (completed-value? stage (BFinal-value current))))
               configuration fuel))

(define (finish configuration edges readback)
  (readback (if (null? edges) configuration (second (last edges)))))

(define (run-D stage computation #:fuel [fuel 100000])
  (define initial (decompose stage computation))
  (finish initial (d-trace stage initial #:fuel fuel) readback-D))

(define (run-Z stage computation #:fuel [fuel 100000])
  (define initial (initial-Z stage computation))
  (finish initial (z-trace stage initial #:fuel fuel) readback-Z))

(define (run-M stage computation #:fuel [fuel 100000])
  (define initial (initial-M stage computation))
  (finish initial (m-trace stage initial #:fuel fuel) readback-M))

(define (run-B stage computation #:fuel [fuel 100000])
  (define initial (initial-B stage computation))
  (finish initial (b-trace stage initial #:fuel fuel) readback-B))
