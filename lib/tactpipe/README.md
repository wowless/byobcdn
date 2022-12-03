# tactpipe

Parses Blizzard TACT Pipe configuration files.

## Example usage

Input:

```
Foo!STRING:0|Bar!STRING:0
## seqn = 42
abc|def
ghi|jkl
```

Invocation:

```javascript
const tactpipe = require('tactpipe');
const str = "...";  // the above
const result = tactpipe.parse(str);
```

Output:

```javascript
{
  data: [
    { Foo: "abc", Bar: "def" },
    { Foo: "ghi", Bar: "jkl" },
  ],
  seqn: 42
}
```
