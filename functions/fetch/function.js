const functions = require('@google-cloud/functions-framework');
const storage = require('@google-cloud/storage');
const axios = require('axios');
const md5 = require('md5');

const bucket = new storage.Storage().bucket(process.env.BYOBCDN_BUCKET);

functions.http('function', async (req, res) => {
  const {url, path, name} = req.body;
  if (name) {
    const file = bucket.file(`byobcdn/${path}/${name}`);
    const [exists] = await file.exists();
    if (!exists) {
      const result = await axios.get(url);
      await file.save(result.data);
    }
    res.json({
      uri: file.cloudStorageURI,
      written: !exists,
    });
  } else {
    const result = await axios.get(url);
    const file = bucket.file(`byobcdn/${path}/${md5(result.data)}`);
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
  }
});
