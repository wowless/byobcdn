const functions = require('@google-cloud/functions-framework');
const {PubSub} = require('@google-cloud/pubsub');
const pubsub = new PubSub();

const products = [
  "wow",
  "wowt",
  "wow_beta",
  "wow_classic",
  "wow_classic_era",
  "wow_classic_era_ptr",
  "wow_classic_ptr",
  "wowxptr",
];

const regions = [
  "cn",
  "eu",
  "kr",
  "sg",
  "tw",
  "us",
];

const endpoints = [
  "cdns",
  "versions",
];

const messages = [];
for (const region of regions) {
  for (const product of products) {
    for (const endpoint of endpoints) {
      messages.push({
        json: {
          endpoint: endpoint,
          product: product,
          region: region,
        },
      });
    }
  }
}

const pub = pubsub.topic('byobcdn-root', {
  batching: {
    maxMessages: messages.length,
  }
});

async function publish(m) {
  await pub.publishMessage(m);
}

functions.http('function', async (_, res) => {
  await Promise.all(messages.map(publish));
  res.send('OK\n');
});
