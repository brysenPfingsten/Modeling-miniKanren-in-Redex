#lang racket

(require redex/reduction-semantics)

(provide define-reference-decomposition-Q)

;; A marked decomposition can focus a fresh-administration redex that has no
;; lean focus.  Q_D therefore relates decompositions by the commuting square:
;; reconstruct, apply Q_R, and decompose in the independently defined lean D.
(define-syntax-rule (define-reference-decomposition-Q marked-decomposition-language-id
                                                      marked-plug-D-id
                                                      source-Q-id
                                                      lean-decompose-id
                                                      decomposition-Q-id)
  (define-judgment-form marked-decomposition-language-id
                        #:contract (decomposition-Q-id D D)
                        #:mode (decomposition-Q-id I O)
                        [(where F_marked (marked-plug-D-id D_marked))
                         (where F_lean (source-Q-id F_marked))
                         (lean-decompose-id F_lean D_lean)
                         ----------------------------------------------------
                         "reference Q_D"
                         (decomposition-Q-id D_marked D_lean)]))
