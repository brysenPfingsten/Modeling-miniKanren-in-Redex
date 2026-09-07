import test from "node:test";
import assert from "node:assert/strict";

import { termToString } from "../src/utils/strings.js";

test("termToString renders dotted-pair JSON explicitly", () => {
  assert.equal(
    termToString({ pair: ["_.0", "_.1"] }),
    "(_.0 . _.1)",
  );
});

test("concrete strings cannot be mistaken for reified variable names", () => {
  assert.equal(termToString({ str: "_.0" }), '"_.0"');
  assert.equal(termToString("_.0"), "_.0");
});

test("boolean query values retain Racket spelling", () => {
  assert.equal(termToString(false), "#f");
  assert.equal(termToString(true), "#t");
});
