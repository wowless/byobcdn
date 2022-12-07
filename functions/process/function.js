const functions = require('@google-cloud/functions-framework');
const {Storage} = require('@google-cloud/storage');
const {CloudTasksClient} = require('@google-cloud/tasks');
const {parse: tactcfg} = require('tactcfg');
const {parse: tactpipe} = require('tactpipe');
const {Parser} = require('binary-parser');
const assert = require('node:assert');
const md5 = require('md5');

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

const archiveIndexFooterParser = new Parser()
  .buffer("tocChecksum", { length: 8 })
  .uint8("version", { assert: 1 })
  .uint8("f3", { assert: 0 })
  .uint8("f4", { assert: 0 })
  .uint8("blockSize", { assert: 4 })
  .uint8("offsetBytes", { assert: 4 })
  .uint8("sizeBytes", { assert: 4 })
  .uint8("keySize", { assert: 16 })
  .uint8("checksumSize", { assert: 8 })
  .uint32le("numElements")
  .buffer("checksum", { length: 8 });

function sub(buf, offset, size) {
  return buf.subarray(offset, offset + size);
}

function parseArchiveIndex(content, name) {
  const footerOffset = content.length - 28;
  assert(footerOffset >= 0, "footer length");
  const footerBytes = content.subarray(footerOffset);
  assert.strictEqual(md5(footerBytes), name, "footer checksum");
  const blockSize = 4096;
  const bytesPerBlock = blockSize + 24;
  assert.strictEqual(footerOffset % bytesPerBlock, 0, "content size");
  const footer = archiveIndexFooterParser.parse(footerBytes);
  const numBlocks = Math.trunc(footerOffset / bytesPerBlock);
  const blockHashesOffset = footerOffset - numBlocks * 8;
  const lastEntriesOffset = blockHashesOffset - numBlocks * 16;
  assert.strictEqual(
    md5(content.subarray(lastEntriesOffset, footerOffset)).substring(0, 16),
    footer.tocChecksum.toString('hex'),
    "toc checksum");
  assert.strictEqual(
    md5(Buffer.concat([
      content.subarray(footerOffset + 8, footerOffset + 20),
      Buffer.from('\0'.repeat(8)),
    ])).substring(0, 16),
    footer.checksum.toString('hex'),
    "internal footer checksum");
  const result = [];
  for (let i = 0; i < numBlocks; ++i) {
    const block = sub(content, blockSize * i, blockSize);
    const lastEntry = sub(content, lastEntriesOffset + i * 16, 16).toString('hex');
    const blockHash = sub(content, blockHashesOffset + i * 8, 8).toString('hex');
    assert.strictEqual(md5(block).substring(0, 16), blockHash, "block hash");
    let found = false;
    for (let p = 0; p <= blockSize - 24 && !found; p += 24) {
      const ekey = block.subarray(p, p + 16).toString('hex');
      const size = block.readUInt32BE(p + 16);
      const offset = block.readUInt32BE(p + 20);
      result.push({
        ekey: ekey,
        offset: offset,
        size: size,
      });
      found = ekey == lastEntry;
    }
    assert(found, "last key found");
  }
  return result;
}

const handlers = [
  {
    name: 'tact product version',
    pattern: /^byobcdn\/tact\/[^/]+\/[^/]+\/versions\//,
    tasks: function*(content) {
      const config = tactpipe(content.toString()).data[0];
      yield mkfetchtask({
        path: 'tact/build',
        url: mkurl('config', config.BuildConfig),
      });
      yield mkfetchtask({
        path: 'tact/cdn',
        url: mkurl('config', config.CDNConfig),
      });
    },
  },
  {
    name: 'tact cdn config',
    pattern: /^byobcdn\/tact\/cdn\/[0-9a-f]+$/,
    tasks: function*(content) {
      for (const archive of tactcfg(content.toString()).data.archives) {
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
    },
  },
  {
    name: 'archive index',
    pattern: /^byobcdn\/index\/[0-9a-f]+$/,
    tasks: function*(content, name, bucketname) {
      const archiveName = name.slice(-32);
      const bucket = storage.bucket(bucketname);
      const map = new Map();
      for (const entry of parseArchiveIndex(content, archiveName)) {
        const value = {
          offset: entry.offset,
          size: entry.size,
        };
        if (!map.has(entry.ekey)) {
          map.set(entry.ekey, [value]);
        } else {
          map.get(entry.ekey).push(value);
        }
      }
      for (const [k, v] of map.entries()) {
        yield bucket.file(`byobcdn/ekey/${k}/${archiveName}`).save(JSON.stringify(v));
      }
    },
  },
];

functions.http('function', async (req, res) => {
  const {bucket, name} = req.body;
  for (const handler of handlers) {
    if (name.match(handler.pattern)) {
      var total = 0;
      const tasks = [];
      const [content] = await storage.bucket(bucket).file(name).download();
      for (const task of handler.tasks(content, name, bucket)) {
        total++;
        tasks.push(task);
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
