import test from "node:test";
import assert from "node:assert/strict";

import {
  deriveStateSelectionUpdate,
  deriveToolbarState,
} from "../src/utils/app_state.js";

test("deriveToolbarState enables editing controls only when runnable", () => {
  assert.deepEqual(
    deriveToolbarState({
      isFrozen: false,
      code: "(run* (q) (== q 'cat))",
      isExampleLoading: false,
      isAtStart: true,
      isAtEnd: false,
    }),
    {
      canStart: true,
      canReset: false,
      canBack: false,
      canStep: false,
    },
  );
});

test("deriveToolbarState exposes step navigation from semantic start/end flags", () => {
  assert.deepEqual(
    deriveToolbarState({
      isFrozen: true,
      code: "(run* (q) (== q 'cat))",
      isExampleLoading: false,
      isAtStart: false,
      isAtEnd: false,
    }),
    {
      canStart: false,
      canReset: true,
      canBack: true,
      canStep: true,
    },
  );
});

test("deriveToolbarState disables reset at semantic start", () => {
  assert.deepEqual(
    deriveToolbarState({
      isFrozen: true,
      code: "(run* (q) (== q 'cat))",
      isExampleLoading: false,
      isAtStart: true,
      isAtEnd: false,
    }),
    {
      canStart: false,
      canReset: false,
      canBack: false,
      canStep: true,
    },
  );
});

test("deriveStateSelectionUpdate ignores nodes without state", () => {
  assert.equal(
    deriveStateSelectionUpdate({
      substitutionData: [],
      trailData: [],
      sId: null,
    }),
    null,
  );
});

test("deriveStateSelectionUpdate retains state-bearing node rows", () => {
  const substitutionData = [{ left: "_.0", right: "cat" }];
  const trailData = [{ left: "_.0", right: "cat" }];

  assert.deepEqual(
    deriveStateSelectionUpdate({
      substitutionData,
      trailData,
      sId: "state-6",
    }),
    {
      stateId: "state-6",
      substitutionData,
      trailData,
    },
  );
});

test("deriveStateSelectionUpdate accepts falsy state IDs", () => {
  for (const stateId of [0, false]) {
    assert.deepEqual(
      deriveStateSelectionUpdate({
        substitutionData: [],
        trailData: [],
        sId: stateId,
      }),
      {
        stateId,
        substitutionData: [],
        trailData: [],
      },
    );
  }
});
