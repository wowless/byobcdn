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

const handlers = [
  {
    name: 'tact product version',
    pattern: /^byobcdn\/tact\/[^/]+\/[^/]+\/versions\//,
    tasks: function*(content) {
      const config = tactpipe(content.toString()).data[0];
      yield {
        path: 'tact/build',
        url: mkurl('config', config.BuildConfig),
      };
      yield {
        path: 'tact/cdn',
        url: mkurl('config', config.CDNConfig),
      };
    },
  },
  {
    name: 'tact cdn config',
    pattern: /^byobcdn\/tact\/cdn\/[0-9a-f]+$/,
    tasks: function*(content) {
      for (const archive of tactcfg(content.toString()).data.archives) {
        yield {
          name: archive,
          path: 'index',
          url: mkurl('data', archive, '.index'),
        };
        yield {
          name: archive,
          path: 'archive',
          url: mkurl('data', archive),
        };
      }
    },
  },
];

functions.http('function', async (req, res) => {
  const {bucket, name} = req.body;
  const file = storage.bucket(bucket).file(name);
  for (const handler of handlers) {
    if (file.name.match(handler.pattern)) {
      var total = 0;
      const tasks = [];
      for (const task of handler.tasks(await file.download())) {
        total++;
        tasks.push(mktask(task));
        if (tasks.length >= 20) {
          await Promise.all(tasks);
          tasks.length = 0;
        }
      }
      await Promise.all(tasks);
      res.json({
        name: handler.name,
        count: total,
      });
      return;
    }
  }
  res.json({});
});
