const axios = require('axios');
const functions = require('@google-cloud/functions-framework');
const md5 = require('md5');
const storage = require('@google-cloud/storage');
const { Datastore } = require('@google-cloud/datastore');

const bucket = new storage.Storage().bucket(process.env.BYOBCDN_BUCKET);
const datastore = new Datastore();

functions.cloudEvent('function', async (cloudEvent) => {
  const q = JSON.parse(Buffer.from(cloudEvent.data.message.data, 'base64').toString());
  const timestamp = new Date();
  const result = await axios.get(`http://${q.region}.patch.battle.net:1119/${q.product}/${q.endpoint}`);
  const hash = md5(result.data);
  const path = `byobcdn/tactpoints/${q.endpoint}/${hash}`;
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
  await datastore.save({
    key: datastore.key(['TactPoint']),
    data: {
      endpoint: q.endpoint,
      hash: hash,
      product: q.product,
      region: q.region,
      timestamp: timestamp,
    }
  });
});
