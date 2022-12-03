tactpipe = schema:schemaline seqn:seqnline data:dataline* {
  return {
    data: data.map(d => {
      const r = {};
      for (const [i, f] of d.entries()) {
        r[schema[i]] = f;
      }
      return r;
    }),
    seqn: seqn,
  };
}
schemaline = first:schemapart rest:("|" @schemapart)* "\n" {
  return [first, ...rest]
}
schemapart = name:$[a-zA-Z]+ "!" [a-zA-Z]+ ":" [0-9]+ {
  return name
}
seqnline = "## seqn = " seqn:$[0-9]+ "\n" {
  return parseInt(seqn, 10);
}
dataline = first:$[^|\n]* rest:("|" @$[^|\n]*)* "\n" {
  return [first, ...rest]
}
