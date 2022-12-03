const parser = require('./grammar');
exports.parse = s => {
  return parser.parse(s);
};
