# Temporary Adapters To Remove

This file tracks tactical shims and adapters that are being tolerated during
the frontier-machine refactor. None of these exist for compatibility; they are
temporary scaffolding and should be removed once the active path is fully
frontier-native.

## Current list

- `racket-server/src/search-lattice/canonical-adapter.rkt`
  - `canonical-flat->search-frontier`
  - `canonical-flat->calls-config`
  - Purpose now: bridge the still-flat canonical wire/config shape
    `(Γ s as)` into the internal frontier machine.
  - Removal trigger: app/runtime/tests initialize directly from a frontier
    config, or the canonical target itself becomes frontier-native.

- Flat canonical wire shape `(Γ s as)`
  - Purpose now: keep the transpiler boundary stable while the internal search
    machine is being refactored.
  - Removal trigger: transpiler, syntax checks, runtime, and JSON projection all
    agree on a frontier-native active config shape.

- `canonical/config` as a flat parser target
  - Purpose now: neutral, search-lattice-native syntax gate while still using a
    flat canonical form.
  - Removal trigger: the active target directly validates the frontier machine,
    making the flat search-tree-plus-stream staging form unnecessary.
