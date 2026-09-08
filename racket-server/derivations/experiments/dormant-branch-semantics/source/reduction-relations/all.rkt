#lang racket

(require (only-in "./core-red.rkt"
                  core-red)
         (only-in "./relcall-red.rkt"
                  relcall-red)
         (only-in "./delay-red.rkt"
                  delay-red)
         (only-in "./disj-red.rkt"
                  disj-red)
         (only-in "./search-red.rkt"
                  search-red)
         (only-in "./search-relcall-red.rkt"
                  search-relcall-red)
         (only-in "./search-dfs-red.rkt"
                  search-dfs-red)
         (only-in "./search-dfs-relcall-red.rkt"
                  search-dfs-relcall-red)
         (only-in "./search-flip-red.rkt"
                  search-flip-red)
         (only-in "./search-flip-relcall-red.rkt"
                  search-flip-relcall-red)
         (only-in "./rail-red.rkt"
                  rail-red)
         (only-in "./rail-relcall-red.rkt"
                  rail-relcall-red))

(provide
 ;; Surfaced call-bearing reduction relations.
 relcall-red
 search-relcall-red
 search-dfs-relcall-red
 search-flip-relcall-red
 rail-relcall-red

 ;; Internal lattice reduction relations kept for staging, comparison, and tests.
 core-red
 delay-red
 disj-red
 search-red
 search-dfs-red
 search-flip-red
 rail-red)
