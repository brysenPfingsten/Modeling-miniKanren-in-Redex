#lang racket

(require rackunit
         rackunit/text-ui
         "../framework/decomposition-instance-tests.rkt"
         "../framework/stage-generators-tests.rkt"
         "../framework/core-source-schema-tests.rkt"
         "../framework/core-stage-schema-tests.rkt"
         "../framework/core-stage-extension-tests.rkt"
         "../generated/core/s/column-tests.rkt"
         "../generated/core/e/column-tests.rkt"
         "../generated/core/source/tests.rkt"
         "../generated/core/stages/tests.rkt"
         "../oracles/core/tests.rkt"
         "./core-matrix-tests.rkt"
         "./core-s-horizontal-tests.rkt"
         "./dependency-boundary-tests.rkt")

(provide SEARCH-LATTICE-MATRIX-SEED)

(define/provide-test-suite SEARCH-LATTICE-MATRIX-SEED
  DECOMPOSITION-FRAMEWORK-TESTS
  STAGE-GENERATOR-SMOKE
  CORE-SOURCE-SCHEMA-TESTS
  CORE-STAGE-SCHEMA-TESTS
  CORE-STAGE-EXTENSION-TESTS
  GENERATED-CORE-S-COLUMN
  GENERATED-CORE-E-COLUMN
  GENERATED-CORE-SOURCES
  GENERATED-CORE-STAGES
  CORE-SOURCE-ORACLE-TESTS
  CORE-MATRIX-SEED
  CORE-S-HORIZONTAL
  DEPENDENCY-BOUNDARY)

(module+ test
  (run-tests SEARCH-LATTICE-MATRIX-SEED))
