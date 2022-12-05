const functions = require('@google-cloud/functions-framework');
const storage = require('@google-cloud/storage');
const axios = require('axios');
const md5 = require('md5');

const bucket = new storage.Storage().bucket(process.env.BYOBCDN_BUCKET);

functions.http('function', async (req, res) => {
  const {url, path, name} = req.body;
  const result = await axios.get(url);
  const file = bucket.file(`byobcdn/${path}/${name || md5(result.data)}`);
  var written = false;
  try {
    await file.save(result.data, {
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
});
