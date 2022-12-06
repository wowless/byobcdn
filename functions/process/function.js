const functions = require('@google-cloud/functions-framework');
const {Storage} = require('@google-cloud/storage');
const {CloudTasksClient} = require('@google-cloud/tasks');
const {parse: tactcfg} = require('tactcfg');
const {parse: tactpipe} = require('tactpipe');

const storage = new Storage();
const taskclient = new CloudTasksClient();

async function mktask(body) {
  return await taskclient.createTask({
    parent: process.env.BYOBCDN_FETCH_QUEUE,
    task: {
      httpRequest: {
        body: Buffer.from(JSON.stringify(body)).toString('base64'),
        headers: {
          'Content-Type': 'application/json',
        },
        httpMethod: 'POST',
        oidcToken: {
          serviceAccountEmail: process.env.BYOBCDN_FETCH_INVOKER,
        },
        url: process.env.BYOBCDN_FETCH_ENDPOINT,
      },
    },
  });
}

function mkurl(kind, hash, suffix) {
  const ab = hash.slice(0, 2);
  const cd = hash.slice(2, 4);
  // TODO get host and path prefix from cdns files
  return `http://level3.blizzard.com/tpr/wow/${kind}/${ab}/${cd}/${hash}${suffix || ''}`;
}

functions.http('function', async (req, res) => {
  const {bucket, name} = req.body;
  const file = storage.bucket(bucket).file(name);
  if (file.name.match(/^byobcdn\/tact\/[^/]+\/[^/]+\/versions\//)) {
    const content = await file.download();
    const config = tactpipe(content.toString()).data[0];
    await mktask({
      path: 'tact/build',
      url: mkurl('config', config.BuildConfig),
    });
    await mktask({
      path: 'tact/cdn',
      url: mkurl('config', config.CDNConfig),
    });
  } else if (file.name.match(/^byobcdn\/tact\/cdn\/[0-9a-f]+$/)) {
    const content = await file.download();
    const tasks = [];
    for (const archive of tactcfg(content.toString()).data.archives) {
      tasks.push(mktask({
        name: archive,
        path: 'index',
        url: mkurl('data', archive, '.index'),
      }));
      tasks.push(mktask({
        name: archive,
        path: 'archive',
        url: mkurl('data', archive),
      }));
      if (tasks.length >= 20) {
        await Promise.all(tasks);
        tasks.length = 0;
      }
    }
    await Promise.all(tasks);
  }
  res.json({});
});
