export const DEFAULT_SEARCH_STRATEGY = Object.freeze({
  scheduler: "rail",
});

export const SCHEDULER_OPTIONS = Object.freeze([
  Object.freeze({ value: "dfs", label: "No Interleave" }),
  Object.freeze({ value: "flip", label: "Flip-Flop" }),
  Object.freeze({ value: "rail", label: "Railroad" }),
]);
