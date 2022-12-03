const assert = require("node:assert/strict");
const tactpipe = require("./tactpipe");
const actual = tactpipe.parse("a!b:0|c!d:0\n## seqn = 42\ne|f\ng|h\n");
const expected = {
  data: [
    { a: "e", c: "f" },
    { a: "g", c: "h" },
  ],
  seqn: 42,
};
assert.deepStrictEqual(actual, expected);
