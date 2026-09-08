export const DEFAULT_SEARCH_STRATEGY = Object.freeze({
  scheduler: "rail",
});

export const DEFAULT_SEARCH_MODEL = "lattice";

export const SEARCH_MODEL_OPTIONS = Object.freeze([
  Object.freeze({ value: "lattice", label: "Strict scheduler lattice" }),
  Object.freeze({ value: "strict", label: "Strict reference (Flip)" }),
]);

export const SCHEDULER_OPTIONS = Object.freeze([
  Object.freeze({ value: "dfs", label: "No Interleave" }),
  Object.freeze({ value: "flip", label: "Flip-Flop" }),
  Object.freeze({ value: "rail", label: "Railroad" }),
]);

export function buildSearchStrategy(
  model = DEFAULT_SEARCH_MODEL,
  scheduler = DEFAULT_SEARCH_STRATEGY.scheduler,
) {
  switch (model) {
    case "lattice": return { scheduler };
    case "strict": return { model: "strict" };
    default: throw new Error(`Unknown search model: ${model}`);
  }
}
