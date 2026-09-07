import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";

import { exampleById, exampleOptions } from "../src/utils/example_programs.js";
import {
  buildSearchStrategy,
  DEFAULT_SEARCH_MODEL,
  DEFAULT_SEARCH_STRATEGY,
  SCHEDULER_OPTIONS,
  SEARCH_MODEL_OPTIONS,
} from "../src/utils/search_strategy.js";
import {
  buildInitOptions,
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

test("buildInitOptions carries the selected structured search strategy", () => {
  assert.deepEqual(
    buildInitOptions(
      "(run* (q) (== q 'cat))",
      "mini",
      DEFAULT_COMPILE_PROFILE,
      DEFAULT_SEARCH_STRATEGY,
    ),
    {
      text: "(run* (q) (== q 'cat))",
      sourceMode: "mini",
      compileProfile: DEFAULT_COMPILE_PROFILE,
      searchStrategy: DEFAULT_SEARCH_STRATEGY,
    },
  );
});

test("exampleOptions exposes stable ids instead of raw program text", () => {
  const options = exampleOptions();
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

test("lattice remains the default with exactly its three scheduler choices", () => {
  assert.equal(DEFAULT_SEARCH_MODEL, "lattice");
  assert.deepEqual(DEFAULT_SEARCH_STRATEGY, { scheduler: "rail" });
  assert.deepEqual(buildSearchStrategy(), DEFAULT_SEARCH_STRATEGY);
  assert.deepEqual(
    SCHEDULER_OPTIONS,
    [
      { value: "dfs", label: "No Interleave" },
      { value: "flip", label: "Flip-Flop" },
      { value: "rail", label: "Railroad" },
    ],
  );
  assert.deepEqual(SEARCH_MODEL_OPTIONS, [
    { value: "lattice", label: "Lattice search" },
    { value: "strict", label: "Strict Search" },
  ]);
});

test("strict requests omit the remembered lattice scheduler and preserve source options", () => {
  const source = "(run* (q) (== q 'cat))";
  const profile = { conjAssoc: "right", disjAssoc: "left", delayPlacement: "disj" };
  for (const { value: scheduler } of SCHEDULER_OPTIONS) {
    assert.deepEqual(buildSearchStrategy("lattice", scheduler), { scheduler });
    for (const sourceMode of ["mini", "micro"]) {
      assert.deepEqual(
        buildInitOptions(source, sourceMode, profile, buildSearchStrategy("strict", scheduler)),
        { ...buildSourceOptions(source, sourceMode, profile), searchStrategy: { model: "strict" } },
      );
    }
  }
  assert.throws(() => buildSearchStrategy("unknown"), /Unknown search model/);
});

test("search UI selects a runtime separately and shows schedulers only for lattice", () => {
  const appSource = readFileSync(new URL("../src/App.jsx", import.meta.url), "utf8");
  const headerSource = readFileSync(
    new URL("../src/components/CodeHeader.jsx", import.meta.url),
    "utf8",
  );
  assert.match(headerSource, /search-model/);
  assert.match(headerSource, /searchModelValue === "lattice" && renderRadioGroup/);
  assert.match(headerSource, /search-scheduler/);
  assert.doesNotMatch(headerSource, /search-hoist|hoistOptions|"Hoist"/);
  assert.doesNotMatch(appSource, /HOIST_OPTIONS|onSearchStrategyChange/);
});

test("switching runtime keeps the lattice scheduler and source settings, and freezes during runs", () => {
  const appSource = readFileSync(new URL("../src/App.jsx", import.meta.url), "utf8");
  const headerSource = readFileSync(new URL("../src/components/CodeHeader.jsx", import.meta.url), "utf8");
  const modelHandler = appSource.match(/const handleSearchModelChange = [\s\S]*?\n {2}};/)?.[0];
  assert.ok(modelHandler);
  assert.match(modelHandler, /if \(isFrozen\) return;/);
  assert.match(modelHandler, /setSearchModel\(model\)/);
  assert.doesNotMatch(modelHandler, /setLatticeScheduler|setCompileProfile|setSourceMode|setCode/);
  assert.match(appSource, /buildSearchStrategy\(searchModel, latticeScheduler\)/);
  assert.match(headerSource, /disabled=\{isFrozen\}/);
});

test("trace navigation preserves selected configuration and reset thaws controls", () => {
  const appSource = readFileSync(new URL("../src/App.jsx", import.meta.url), "utf8");
  const navigationSource = appSource.match(
    /const handleStep[\s\S]*?(?=\n {2}useEffect\()/,
  )?.[0];

  assert.ok(navigationSource);
  assert.match(navigationSource, /const handleBack/);
  assert.match(navigationSource, /const handleReset/);
  assert.match(navigationSource, /deriveThawedEditorState/);
  assert.match(navigationSource, /setFrozen\(nextState\.isFrozen\)/);
  assert.doesNotMatch(
    navigationSource,
    /setSourceMode|setCompileProfile|setLatticeScheduler|setSearchModel/,
  );
});

test("factored continuation example replaces the retired hoist witness", () => {
  const example = exampleById("factored-continuation");
  assert.equal(example.label, "factored continuation");
  assert.match(example.miniSource, /'factored/);
  assert.match(example.miniSource, /'continuation/);
  assert.equal(exampleById("hoist-witness"), null);
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
