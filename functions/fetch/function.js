const functions = require('@google-cloud/functions-framework');
const storage = require('@google-cloud/storage');
const axios = require('axios');
const md5 = require('md5');

const bucket = new storage.Storage().bucket(process.env.BYOBCDN_BUCKET);

async function fetch(url) {
  const result = await axios({
    method: 'get',
    responseType: 'arraybuffer',
    url: url,
  });
  return result.data;
}

functions.http('function', async (req, res) => {
  const {url, path, name} = req.body;
  if (name) {
    const file = bucket.file(`byobcdn/${path}/${name}`);
    const [exists] = await file.exists();
    if (!exists) {
      const result = await fetch(url);
      await file.save(result);
    }
    res.json({
      uri: file.cloudStorageURI,
      written: !exists,
    });
  } else {
    const result = await fetch(url);
    const file = bucket.file(`byobcdn/${path}/${md5(result)}`);
    var written = false;
    try {
      await file.save(result, {
        preconditionOpts: {
          ifGenerationMatch: 0,
        }
      });
      written = true;
    } catch (error) {
      if (error.code != 412) {
        throw error;
      }
    }
    res.json({
      uri: file.cloudStorageURI,
      written: written,
    });
  }
});
