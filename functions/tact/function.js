const axios = require('axios');
const functions = require('@google-cloud/functions-framework');
const md5 = require('md5');
const storage = require('@google-cloud/storage');

const bucket = new storage.Storage().bucket(process.env.BYOBCDN_BUCKET);

functions.cloudEvent('function', async (cloudEvent) => {
  const q = JSON.parse(Buffer.from(cloudEvent.data.message.data, 'base64').toString());
  const result = await axios.get(`http://${q.region}.patch.battle.net:1119/${q.product}/${q.endpoint}`);
  const hash = md5(result.data);
  const path = `byobcdn/tact/${q.region}/${q.product}/${q.endpoint}/${hash}`;
  try {
    await bucket.file(path).save(result.data, {
      preconditionOpts: {
        ifGenerationMatch: 0,
      }
    });
  } catch (error) {
    if (error.code != 412) {
      throw error;
    }
  }
});
