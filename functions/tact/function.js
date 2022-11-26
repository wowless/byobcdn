const axios = require('axios');
const functions = require('@google-cloud/functions-framework');
const md5 = require('md5');
const storage = require('@google-cloud/storage');

const bucket = new storage.Storage().bucket('byobcdn.wowless.dev');

functions.http('function', async (req, res) => {
  const q = req.query;
  const result = await axios.get(`http://us.patch.battle.net:1119/${q.product}/${q.endpoint}`);
  const hash = md5(result.data);
  const path = `byobcdn/tact/${q.product}/${q.endpoint}/${hash}`;
  await bucket.file(path).save(result.data);
  res.send(`gs://${bucket.name}/${path}\n`);
});
