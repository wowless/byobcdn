const functions = require('@google-cloud/functions-framework');
const axios = require('axios');
functions.http('function', async (req, res) => {
  console.log(await axios.get('http://us.patch.battle.net:1119/wow/versions'))
  res.send('OK')
});
