import test from "node:test";
import assert from "node:assert/strict";

import { addColors } from "../src/utils/treeSetup.js";

test("addColors preserves binary Goal-Conj nesting", () => {
  const tree = {
    name: "Goal-Conj",
    children: [
      {
        name: "Goal-Conj",
        children: [
          { name: "Goal-Delay", children: [{ name: "Rel-Call" }] },
          { name: "Unify" },
        ],
      },
      { name: "Unify" },
    ],
  };

  const result = addColors(tree);

  assert.equal(result.name, "Goal-Conj");
  assert.equal(result.children.length, 2);
  assert.equal(result.children[0].name, "Goal-Conj");
  assert.equal(result.children[0].children.length, 2);
});

test("addColors preserves the search-tree color through an answer prefix", () => {
  const tree = {
    name: "Answer",
    children: [
      {
        name: "<-+",
        children: [
          { name: "Answer" },
          { name: "Unify" },
        ],
      },
    ],
  };

  const result = addColors(tree);

  assert.equal(result.children[0].color, "#ff8000");
});

test("addColors keeps the active edge colored when a disjunction points at an answer", () => {
  const tree = {
    name: "<-+",
    children: [
      { name: "Answer" },
      { name: "Unify" },
    ],
  };

  const result = addColors(tree);

  assert.equal(result.children[0].color, "#ff8000");
});

test("addColors keeps the active edge colored through a spine prefix to an answer", () => {
  const tree = {
    name: "Freshened",
    children: [
      {
        name: "<-+",
        children: [
          { name: "Answer" },
          { name: "Unify" },
        ],
      },
    ],
  };

  const result = addColors(tree);

  assert.equal(result.color, "#ff8000");
  assert.equal(result.children[0].color, "#ff8000");
  assert.equal(result.children[0].children[0].color, "#ff8000");
});

test("addColors carries spine color through freshened nodes", () => {
  const tree = {
    name: "Freshened",
    children: [
      {
        name: "<-+",
        children: [
          { name: "Answer" },
          { name: "Unify" },
        ],
      },
    ],
  };

  const result = addColors(tree);

  assert.equal(result.color, "#ff8000");
  assert.equal(result.children[0].color, "#ff8000");
  assert.equal(result.children[0].children[0].color, "#ff8000");
});

test("addColors keeps the active edge colored through nested rail disjunctions", () => {
  const tree = {
    name: "Freshened",
    children: [
      {
        name: "<-+",
        children: [
          {
            name: "+->",
            children: [
              { name: "Goal-Disj", children: [{ name: "Rel-Call" }, { name: "Unify" }] },
              { name: "Answer" },
            ],
          },
          {
            name: "+->",
            children: [
              { name: "Goal-Disj", children: [{ name: "Rel-Call" }, { name: "Unify" }] },
              { name: "Unify" },
            ],
          },
        ],
      },
    ],
  };

  const result = addColors(tree);

  assert.equal(result.color, "#ff8000");
  assert.equal(result.children[0].color, "#ff8000");
  assert.equal(result.children[0].children[0].color, "#ff8000");
  assert.equal(result.children[0].children[0].children[1].color, "#ff8000");
});

test("addColors carries the active path through delay nodes", () => {
  const tree = {
    name: "Freshened",
    children: [
      {
        name: "Bounced",
        children: [
          {
            name: "Delay",
            children: [
              {
                name: "+->",
                children: [
                  { name: "Goal-Disj", children: [{ name: "Rel-Call" }, { name: "Unify" }] },
                  { name: "Goal-Disj", children: [{ name: "Rel-Call" }, { name: "Unify" }] },
                ],
              },
            ],
          },
        ],
      },
    ],
  };

  const result = addColors(tree);

  assert.equal(result.color, "#ff8000");
  assert.equal(result.children[0].color, "#ff8000");
  assert.equal(result.children[0].children[0].color, "#ff8000");
  assert.equal(result.children[0].children[0].children[0].color, "#ff8000");
  assert.equal(result.children[0].children[0].children[0].children[1].color, "#ff8000");
});
