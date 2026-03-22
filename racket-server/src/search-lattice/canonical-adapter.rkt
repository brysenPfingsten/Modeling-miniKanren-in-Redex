#lang racket

(provide canonical-flat->calls-config
         canonical-flat->search-frontier)

(define (canonical-work->frontier s)
  (match s
    ['(empty-tree) '(empty-tree)]
    [`(,g ,σ) `(,g ,σ)]
    [`(,f_1 × ,g ,c)
     `(,(canonical-work->frontier f_1) × ,g ,c)]
    [`(,f_1 <-+ ,f_2)
     `(,(canonical-work->frontier f_1) <-+ ,(canonical-work->frontier f_2))]
    [`(,f_1 +-> ,f_2)
     `(,(canonical-work->frontier f_1) +-> ,(canonical-work->frontier f_2))]
    [`(delay ,f_1)
     `(delay ,(canonical-work->frontier f_1))]
    [other
     (error 'canonical-work->frontier
            "expected canonical work tree, got ~e"
            other)]))

(define (canonical-stream->frontier as f)
  (match as
    ['(empty-stream) f]
    [`(⊤ ,σ)
     `((⊤ ,σ) + ,f)]
    [`((⊤ ,σ) + ,as_tail)
     `((⊤ ,σ) + ,(canonical-stream->frontier as_tail f))]
    [other
     (error 'canonical-stream->frontier
            "expected canonical answer stream, got ~e"
            other)]))

(define (canonical-flat->search-frontier cfg)
  (match cfg
    [`(,_Γ ,s ,as)
     (canonical-stream->frontier as (canonical-work->frontier s))]
    [other
     (error 'canonical-flat->search-frontier
            "expected flat canonical config '(Γ s as), got ~e"
            other)]))

(define (canonical-flat->calls-config cfg)
  (match cfg
    [`(,Γ ,_s ,_as)
     `(,Γ ,(canonical-flat->search-frontier cfg))]
    [other
     (error 'canonical-flat->calls-config
            "expected flat canonical config '(Γ s as), got ~e"
            other)]))
