const functions = require('@google-cloud/functions-framework');
const storage = require('@google-cloud/storage');
const axios = require('axios');
const md5 = require('md5');

const bucket = new storage.Storage().bucket(process.env.BYOBCDN_BUCKET);

functions.http('function', async (req, res) => {
  const result = await axios.get(req.body.url);
  const file = bucket.file(`byobcdn/${req.body.path}/${md5(result.data)}`);
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
