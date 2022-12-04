const storage = require('@google-cloud/storage');
const tasks = require('@google-cloud/tasks');
const tactpipe = require('tactpipe');

const bucket = new storage.Storage().bucket(process.env.BYOBCDN_BUCKET);
const taskclient = new tasks.CloudTasksClient();

async function mktask(body) {
  return await taskclient.createTask({
    parent: taskclient.queuePath('www-wowless-dev', 'us-central1', 'byobcdn-fetch'),
    task: {
      httpRequest: {
        body: Buffer.from(JSON.stringify(body)).toString('base64'),
        headers: {
          'Content-Type': 'application/json',
        },
        httpMethod: 'POST',
        oidcToken: {
          serviceAccountEmail: 'byobcdn-fetch-invoker@www-wowless-dev.iam.gserviceaccount.com',
        },
        url: 'https://us-central1-www-wowless-dev.cloudfunctions.net/byobcdn-fetch',
      },
    },
  });
}

function mkurl(kind, hash) {
  const ab = hash.slice(0, 2);
  const cd = hash.slice(2, 4);
  // TODO get host and path prefix from cdns files
  return `http://level3.blizzard.com/tpr/wow/${kind}/${ab}/${cd}/${hash}`;
}

exports.watch = async (event, _) => {
  const file = bucket.file(event.name);
  if (file.name.match(/^byobcdn\/tact\/[^/]+\/[^/]+\/versions\//)) {
    const content = await file.download();
    const config = tactpipe.parse(content.toString()).data[0];
    await mktask({
      path: 'tact/build',
      url: mkurl('config', config.BuildConfig),
    });
    await mktask({
      path: 'tact/cdn',
      url: mkurl('config', config.CDNConfig),
    });
  }
};
