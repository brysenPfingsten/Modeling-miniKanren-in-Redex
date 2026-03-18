import test from "node:test";
import assert from "node:assert/strict";

import { exampleById, examplesForModel } from "../src/utils/example_programs.js";
import { MODEL_IDS } from "../src/utils/model_ids.js";
import {
  buildSourceOptions,
  CONJ_ASSOC_OPTIONS,
  DELAY_PLACEMENT_OPTIONS,
  DEFAULT_COMPILE_PROFILE,
  DISJ_ASSOC_OPTIONS,
  SOURCE_MODE_OPTIONS,
} from "../src/utils/source_defaults.js";

test("buildSourceOptions includes compileProfile for mini source", () => {
  assert.deepEqual(
    buildSourceOptions("(run* (q) (== q 'cat))", "mini", DEFAULT_COMPILE_PROFILE),
    {
      text: "(run* (q) (== q 'cat))",
      sourceMode: "mini",
      compileProfile: DEFAULT_COMPILE_PROFILE,
    },
  );
});

test("buildSourceOptions omits compileProfile for micro source", () => {
  assert.deepEqual(
    buildSourceOptions("(run* (q) (== q 'cat))", "micro", DEFAULT_COMPILE_PROFILE),
    {
      text: "(run* (q) (== q 'cat))",
      sourceMode: "micro",
    },
  );
});

test("examplesForModel exposes stable ids instead of raw program text", () => {
  const options = examplesForModel(MODEL_IDS.L4_RAIL_LAZY);
  assert.equal(options[0].value, "");
  assert.equal(options[0].label, "Examples");
  assert.ok(options.some((opt) => opt.value === "appendoh-1"));
  assert.ok(options.every((opt) => typeof opt.value === "string"));
});

test("exampleById returns the semantic example source of truth", () => {
  const example = exampleById("same");
  assert.equal(example.label, "same");
  assert.match(example.miniSource, /defrel/);
  assert.equal(exampleById("missing-example"), null);
});

test("source mode and compile profile option catalogs expose the expected axes", () => {
  assert.deepEqual(
    SOURCE_MODE_OPTIONS.map(({ value }) => value),
    ["mini", "micro"],
  );
  assert.deepEqual(
    CONJ_ASSOC_OPTIONS.map(({ value }) => value),
    ["left", "right"],
  );
  assert.deepEqual(
    DISJ_ASSOC_OPTIONS.map(({ value }) => value),
    ["left", "right"],
  );
  assert.deepEqual(
    DELAY_PLACEMENT_OPTIONS.map(({ value }) => value),
    ["relbody", "relcall", "disj"],
  );
});
