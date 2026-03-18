export const DEFAULT_SOURCE_MODE = "mini";

export const DEFAULT_COMPILE_PROFILE = Object.freeze({
  conjAssoc: "left",
  disjAssoc: "right",
  delayPlacement: "relbody",
});

export const SOURCE_MODE_OPTIONS = Object.freeze([
  Object.freeze({ value: "mini", label: "miniKanren" }),
  Object.freeze({ value: "micro", label: "microKanren" }),
]);

export function buildSourceOptions(
  text,
  sourceMode = DEFAULT_SOURCE_MODE,
  compileProfile = DEFAULT_COMPILE_PROFILE,
) {
  return sourceMode === "mini"
    ? { text, sourceMode, compileProfile }
    : { text, sourceMode };
}
