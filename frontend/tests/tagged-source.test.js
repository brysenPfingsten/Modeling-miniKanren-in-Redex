import test from "node:test";
import assert from "node:assert/strict";

import { parseTaggedText } from "../src/utils/tagged_source.js";

test("parseTaggedText strips markers and keeps source segments for repeated ids", () => {
  const tagged = "[[d0]](conde [[u1]](== q 'four)[[/u1]] [[u1]](== q 'five)[[/u1]])[[/d0]]";
  const { plain, segments } = parseTaggedText(tagged);

  assert.equal(plain, "(conde (== q 'four) (== q 'five))");
  assert.deepEqual(
    segments.filter(({ id }) => id === "u1").map(({ start, end }) => [start, end]),
    [
      [7, 19],
      [20, 32],
    ],
  );
  assert.deepEqual(
    segments.filter(({ id }) => id === "d0").map(({ start, end }) => [start, end]),
    [[0, plain.length]],
  );
});

test("parseTaggedText accepts hyphenated ids", () => {
  const tagged = "[[fresh-0]](fresh (x) ...)[[/fresh-0]]";
  const { plain, segments } = parseTaggedText(tagged);

  assert.equal(plain, "(fresh (x) ...)");
  assert.deepEqual(segments, [{ id: "fresh-0", start: 0, end: plain.length }]);
});

test("parseTaggedText preserves literal brackets adjacent to both marker boundaries", () => {
  for (const [prefix, suffix] of [["[", "]"], ["[[", "]]"], ["]", "["], ["", "]]"]]) {
    const goal = "(== q 'cat)";
    const { plain, segments } = parseTaggedText(`${prefix}[[u0]]${goal}[[/u0]]${suffix}`);

    assert.equal(plain, `${prefix}${goal}${suffix}`);
    assert.deepEqual(segments, [{ id: "u0", start: prefix.length, end: prefix.length + goal.length }]);
  }
});

test("parseTaggedText preserves conde clauses and nested spans in actual compiler markup", () => {
  // parse-prog/canonical output for a two-clause same relation. The second
  // clause contains a conjunction, so its marker nests around two goal spans.
  const tagged = `(defrel (same x)
  [[d0]](conde
    [[[u1]](== x 'a)[[/u1]]]
    [[[c2]][[u3]](== x 'b)[[/u3]]
    [[n4]](=/= x 'c)[[/n4]][[/c2]]]
  )[[/d0]])

[[f5]](run* (q) [[r6]](same q)[[/r6]])[[/f5]]`;
  const expected = `(defrel (same x)
  (conde
    [(== x 'a)]
    [(== x 'b)
    (=/= x 'c)]
  ))

(run* (q) (same q))`;
  const { plain, segments } = parseTaggedText(tagged);

  assert.equal(plain, expected);
  assert.deepEqual(segments.map(({ id, start, end }) => [id, plain.slice(start, end)]), [
    ["u1", "(== x 'a)"],
    ["u3", "(== x 'b)"],
    ["n4", "(=/= x 'c)"],
    ["c2", "(== x 'b)\n    (=/= x 'c)"],
    ["d0", "(conde\n    [(== x 'a)]\n    [(== x 'b)\n    (=/= x 'c)]\n  )"],
    ["r6", "(same q)"],
    ["f5", "(run* (q) (same q))"],
  ]);
  for (const { id, start, end } of segments) {
    if (id === "u1" || id === "c2") {
      assert.equal(plain[start - 1], "[");
      assert.equal(plain[end], "]");
    }
  }
});

test("parseTaggedText does not treat nested literal brackets as a marker ID", () => {
  const literal = "[[q [r]] [[]] [left[right]]";
  assert.deepEqual(parseTaggedText(literal), { plain: literal, segments: [] });

  const { plain, segments } = parseTaggedText(`[[u0]]${literal}[[/u0]]`);
  assert.equal(plain, literal);
  assert.deepEqual(segments, [{ id: "u0", start: 0, end: literal.length }]);
});

test("parseTaggedText preserves marker text inside strings, including escaped delimiters", () => {
  for (const literal of [
    '"[[u0]]"',
    '"[[/u0]] [[other]] [[/other]]"',
    String.raw`"escaped \" [[/u0]] and \\ [[u0]]"`,
    '"first line\n[[/u0]]\n[[u0]] last line"',
    String.raw`"backslash at the end \\"`,
  ]) {
    const first = `(== q ${literal})`;
    const second = "(== q 'after)";
    const { plain, segments } = parseTaggedText(`[[c0]][[u0]]${first}[[/u0]]\n[[u1]]${second}[[/u1]][[/c0]]`);

    assert.equal(plain, `${first}\n${second}`);
    assert.deepEqual(segments, [
      { id: "u0", start: 0, end: first.length },
      { id: "u1", start: first.length + 1, end: plain.length },
      { id: "c0", start: 0, end: plain.length },
    ]);
  }
});

test("parseTaggedText preserves marker text and quotes inside written symbols", () => {
  for (const literal of [
    "'|[[u0]] [[/u0]]|",
    String.raw`'|a"[[/u0]]\b|`,
    String.raw`'\[\[u0\]\]\|`,
    String.raw`'a\"\|`,
  ]) {
    const goal = `(== q ${literal})`;
    const { plain, segments } = parseTaggedText(`[[u0]]${goal}[[/u0]][[u1]](succeed)[[/u1]]`);

    assert.equal(plain, `${goal}(succeed)`);
    assert.deepEqual(segments, [
      { id: "u0", start: 0, end: goal.length },
      { id: "u1", start: goal.length, end: plain.length },
    ]);
  }
});
