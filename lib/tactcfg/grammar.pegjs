tactpipe = header:headerline "\n" data:dataline* "\n" {
  return {
    data: data.reduce((acc, {key, values}) => {
      acc[key] = values
      return acc
    }, {}),
    name: header,
  };
}
headerline = "# " name:$[^\n]+ "\n" {
  return name
}
dataline = key:$[^ ]+ " =" values:(" " @$[^ \n]+)+ "\n" {
  return {key, values}
}
