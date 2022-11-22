const axios = require('axios');
const functions = require('@google-cloud/functions-framework');
const md5 = require('md5');
const storage = require('@google-cloud/storage');

const bucket = new storage.Storage().bucket('wowless.dev');

functions.http('function', async (req, res) => {
  let result = await axios.get('http://us.patch.battle.net:1119/wow/versions');
  let hash = md5(result.data);
  await bucket.file('byobcdn/content/' + hash).save(result.data);
  res.send(hash);
});
