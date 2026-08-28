import assert from 'node:assert/strict';
import test from 'node:test';

import { deriveStateSelectionUpdate, hasStateSelection } from '../src/utils/stateSelection.js';

test('non-state node clicks preserve the previous state selection', () => {
  const previousSelection = {
    substitutionData: [{ left: 'x', right: 'cat' }],
    trailData: [{ left: 'x', right: 'cat' }],
    stateId: 'selected-state',
  };

  const missingIdUpdate = deriveStateSelectionUpdate({
    substitutionData: [],
    trailData: [],
    hasStateId: false,
  });
  const repeatedWrapperUpdate = deriveStateSelectionUpdate({
    substitutionData: [],
    trailData: [],
    sId: null,
    hasStateId: false,
  });

  assert.equal(missingIdUpdate ?? previousSelection, previousSelection);
  assert.equal(repeatedWrapperUpdate ?? previousSelection, previousSelection);
});

test('state-bearing nodes accept falsy identifiers and empty data', () => {
  for (const stateId of [false, 0]) {
    const update = deriveStateSelectionUpdate({
      substitutionData: [],
      trailData: [],
      sId: stateId,
      hasStateId: true,
    });

    assert.equal(hasStateSelection(stateId), true);
    assert.deepEqual(update, {
      substitutionData: [],
      trailData: [],
      stateId,
    });
  }
});

test('re-clicking a state-bearing goal still applies explicit deselection', () => {
  const update = deriveStateSelectionUpdate({
    substitutionData: [{ left: 'x', right: 'cat' }],
    trailData: [],
    sId: null,
    hasStateId: true,
  });

  assert.deepEqual(update, {
    substitutionData: [{ left: 'x', right: 'cat' }],
    trailData: [],
    stateId: null,
  });
});
