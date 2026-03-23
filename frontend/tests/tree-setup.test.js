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
    name: "Emit",
    children: [
      { name: "Answer" },
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

  assert.equal(result.children[0].color, "green");
  assert.equal(result.children[1].color, "#ff8000");
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
    name: "Stream-Freshened",
    children: [
      {
        name: "Emit",
        children: [
          { name: "Answer" },
          {
            name: "<-+",
            children: [
              { name: "Answer" },
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
  assert.equal(result.children[0].children[0].color, "green");
  assert.equal(result.children[0].children[1].color, "#ff8000");
});

test("addColors carries spine color through freshened nodes", () => {
  const tree = {
    name: "Stream-Freshened",
    children: [
      {
        name: "Emit",
        children: [
          { name: "Answer" },
          {
            name: "<-+",
            children: [
              { name: "Answer" },
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
  assert.equal(result.children[0].children[0].color, "green");
  assert.equal(result.children[0].children[1].color, "#ff8000");
});

test("addColors keeps the active edge colored through nested rail disjunctions", () => {
  const tree = {
    name: "Stream-Freshened",
    children: [
      {
        name: "Emit",
        children: [
          {
            name: "Answer",
          },
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
              { name: "Goal-Disj", children: [{ name: "Rel-Call" }, { name: "Unify" }] },
            ],
          },
        ],
      },
    ],
  };

  const result = addColors(tree);

  assert.equal(result.color, "#ff8000");
  assert.equal(result.children[0].color, "#ff8000");
  assert.equal(result.children[0].children[0].color, "green");
  assert.equal(result.children[0].children[1].color, "#ff8000");
  assert.equal(result.children[0].children[1].children[0].color, "#ff8000");
  assert.equal(result.children[0].children[1].children[0].children[1].color, "#ff8000");
});

test("addColors carries the active path through delay nodes", () => {
  const tree = {
    name: "Stream-Freshened",
    children: [
      {
        name: "Bounced",
        children: [
          {
            name: "Emit",
            children: [
              { name: "Answer" },
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
      },
    ],
  };

  const result = addColors(tree);

  assert.equal(result.color, "#ff8000");
  assert.equal(result.children[0].color, "#ff8000");
  assert.equal(result.children[0].children[0].color, "#ff8000");
  assert.equal(result.children[0].children[0].children[0].color, "green");
  assert.equal(result.children[0].children[0].children[1].color, "#ff8000");
  assert.equal(result.children[0].children[0].children[1].children[0].color, "#ff8000");
  assert.equal(result.children[0].children[0].children[1].children[0].children[1].color, "#ff8000");
});
