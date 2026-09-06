#lang racket
(provide (all-defined-out))

;; Closure conversion removes the run-invariant K from individual records;
;; it remains an explicit argument to every control function.
(struct KDone () #:transparent)                  ; C0
(struct KConj (right k) #:transparent)            ; C1
(struct KDisjLeft (right state k) #:transparent)  ; C2
(struct KDisjRight (left k) #:transparent)        ; C3
(struct KYield (state k) #:transparent)            ; C4
(struct KBindHead (rest continue k) #:transparent); C5
(struct KBindTail (head k) #:transparent)         ; C6
(struct KMergeForced (right k) #:transparent)     ; C7
(struct KBindForced (continue k) #:transparent)   ; C8
(struct KRun (k) #:transparent)                  ; C9
(struct KEmit (state k) #:transparent)            ; C10
(struct KRenderForced (k) #:transparent)          ; C11
(struct KForced (k) #:transparent)                ; C12

(struct GRight (goal) #:transparent)              ; G0
(struct REval (goal state) #:transparent)         ; R0
(struct RMerge (right rest) #:transparent)        ; R1
(struct RBind (rest continue) #:transparent)      ; R2
