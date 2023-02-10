const functions = require('@google-cloud/functions-framework');
const { Storage } = require('@google-cloud/storage');
const { CloudTasksClient } = require('@google-cloud/tasks');
const tactless = require('tactless');

const storage = new Storage();
const taskclient = new CloudTasksClient();

async function mkfetchtask(body) {
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

async function batchit(fn, size, gen) {
  const batch = [];
  let numElements = 0;
  for await (const element of gen()) {
    numElements++;
    batch.push(element);
    if (batch.length == size) {
      await fn(batch);
      batch.length = 0;
    }
  }
  if (batch.length != 0) {
    await fn(batch);
  }
  console.log('processed %d elements', numElements);
}

const handlers = [
  {
    name: 'tact build config',
    pattern: /^byobcdn\/tact\/build\//,
    process: async (content) => {
      const hash = tactless.config(content.toString()).data.encoding[1];
      await mkfetchtask({
        name: hash,
        path: 'encoding',
        url: mkurl('data', hash),
      });
    },
  },
  {
    name: 'tact product version',
    pattern: /^byobcdn\/tactpoints\/versions\//,
    process: async (content) => {
      const config = tactless.pipe(content.toString()).data[0];
      await mkfetchtask({
        path: 'tact/build',
        url: mkurl('config', config.BuildConfig),
      });
      await mkfetchtask({
        path: 'tact/cdn',
        url: mkurl('config', config.CDNConfig),
      });
    },
  },
  {
    name: 'tact cdn config',
    pattern: /^byobcdn\/tact\/cdn\/[0-9a-f]+$/,
    process: async (content) => {
      await batchit(x => Promise.all(x), 20, function* () {
        for (const archive of tactless.config(content.toString()).data.archives) {
          yield mkfetchtask({
            name: archive,
            path: 'index',
            url: mkurl('data', archive, '.index'),
          });
          yield mkfetchtask({
            name: archive,
            path: 'archive',
            url: mkurl('data', archive),
          });
        }
      });
    },
  },
];

functions.http('function', async (req, res) => {
  const { bucket, name } = req.body;
  for (const handler of handlers) {
    if (name.match(handler.pattern)) {
      const [content] = await storage.bucket(bucket).file(name).download();
      await handler.process(content, name);
      res.json({
        name: handler.name,
      });
      return;
    }
  }
  res.json({});
});
