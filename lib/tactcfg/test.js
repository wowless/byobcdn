const assert = require("node:assert/strict");
const tactcfg = require("./tactcfg");
const actual = tactcfg.parse("# moo\n\ncow = a bc def\npig = 1234\n");
const expected = {
  data: {
    cow: ["a", "bc", "def"],
    pig: ["1234"],
  },
  name: "moo",
};
assert.deepStrictEqual(actual, expected);
