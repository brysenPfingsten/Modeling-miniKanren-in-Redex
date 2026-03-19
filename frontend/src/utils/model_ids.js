export const MODEL_IDS = Object.freeze({
  L4_RAIL_LAZY: "l4-rail-lazy",
  L3_DFS_LAZY: "l3-dfs-lazy",
  L3_FLIP_LAZY: "l3-flip-lazy",
  L4_RAIL_EAGER: "l4-rail-eager",
  L3_DFS_EAGER: "l3-dfs-eager",
  L3_FLIP_EAGER: "l3-flip-eager",
});

export const DEFAULT_MODEL_OPTIONS = Object.freeze([
  Object.freeze({
    value: MODEL_IDS.L3_DFS_LAZY,
    label: "(No Interleave, Lazy)",
  }),
  Object.freeze({
    value: MODEL_IDS.L3_FLIP_LAZY,
    label: "(Interleave + Flip-Flop, Lazy)",
  }),
  Object.freeze({
    value: MODEL_IDS.L4_RAIL_LAZY,
    label: "(Interleave + Railroad, Lazy)",
  }),
  Object.freeze({
    value: MODEL_IDS.L3_DFS_EAGER,
    label: "(No Interleave, Eager)",
  }),
  Object.freeze({
    value: MODEL_IDS.L3_FLIP_EAGER,
    label: "(Interleave + Flip-Flop, Eager)",
  }),
  Object.freeze({
    value: MODEL_IDS.L4_RAIL_EAGER,
    label: "(Interleave + Railroad, Eager)",
  }),
]);
