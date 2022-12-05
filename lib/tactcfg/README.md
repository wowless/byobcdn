# tactpipe

Parses Blizzard TACT key-value configuration files.

## Example usage

Input:

```
# Title

foo = bar baz
moo = 123 456
```

Invocation:

```javascript
const tactcfg = require('tactcfg');
const str = "...";  // the above
const result = tactcfg.parse(str);
```

Output:

```javascript
{
  data: {
    foo: ["bar", "baz"],
    moo: ["123", "456"],
  },
  name: "Title"
}
```
