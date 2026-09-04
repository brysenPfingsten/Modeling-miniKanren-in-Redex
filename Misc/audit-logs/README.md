# Audit Log Provenance

The `branch=language-refactor` fields in manifests under this directory record
the branch name at capture time. They do not refer to the later branch that
reused that name.

The authoritative source identity for each audit is its `commit=` field. The
2026-03-02 matrix-step audits record commit
`7436aaa008551bf0562a2394dbeaf249fe36ca32`. Their containing pre-rewrite
history is preserved by the annotated tag
`archive/language-refactor-pre-rewrite-2026-03-28`.

The generated manifests remain unchanged as captured evidence.
