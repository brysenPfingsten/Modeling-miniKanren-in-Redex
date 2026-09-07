export function parseTaggedText(raw) {
  const segments = [];
  let plain = "";
  let lastIndex = 0;
  const stack = [];

  // A conde clause starts with a literal '[' immediately before its first
  // marker. Neither bracket belongs to an ID: in '[[[u0]]', skip the first
  // bracket and recognize '[[u0]]'. Annotations surround goals, so strings,
  // bar-quoted symbols, and escaped symbol characters are literal source.
  const tokenRE = /"(?:\\[\s\S]|[^"\\])*"|\|[^|]*\||\\[\s\S]|\[\[(\/?)([^[\]]+)\]\]/g;
  let m;
  while ((m = tokenRE.exec(raw))) {
    if (m[2] === undefined) continue;

    const close = m[1] === "/";
    const id = m[2];
    const idx = m.index;

    plain += raw.slice(lastIndex, idx);

    if (!close) {
      stack.push({ id, start: plain.length });
    } else {
      for (let i = stack.length - 1; i >= 0; --i) {
        if (stack[i].id === id) {
          const { start } = stack[i];
          stack.splice(i, 1);
          segments.push({ id, start, end: plain.length });
          break;
        }
      }
    }

    lastIndex = idx + m[0].length;
  }

  plain += raw.slice(lastIndex);
  return { plain, segments };
}
