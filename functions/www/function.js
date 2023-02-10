const datastore = new (require('@google-cloud/datastore').Datastore)();
const bucket = new (require('@google-cloud/storage').Storage)().bucket('byobcdn.wowless.dev');
const tactless = require('tactless');

const app = require('express')();
app.set('view engine', 'pug');
app.engine('pug', require('pug').__express);

app.get('/', async (_, res) => {
  const [entities] = await datastore
    .createQuery('TactPoint')
    .order('timestamp', { descending: true })
    .limit(200)
    .run();
  const products = new Map();
  for (const e of entities) {
    if (!products.has(e.product)) {
      products.set(e.product, {
        name: e.product,
      });
    }
    const p = products.get(e.product);
    if (!p[e.endpoint] || p[e.endpoint].timestamp < e.timestamp) {
      p[e.endpoint] = e;
    }
  }
  res.render('index', {
    products: Array
        .from(products.values())
        .sort((a, b) => a.name.localeCompare(b.name))
  });
});

app.get('/archive/:id', async (req, res) => {
  res.render('archive', {
    id: req.params.id,
  });
});

app.get('/build/:id', async (req, res) => {
  const file = bucket.file(`byobcdn/tact/build/${req.params.id}`);
  const [content] = await file.download();
  res.render('buildconfig', {
    config: tactless.config(content.toString()).data,
    id: req.params.id,
  });
});

app.get('/cdn/:id', async (req, res) => {
  const file = bucket.file(`byobcdn/tact/cdn/${req.params.id}`);
  const [content] = await file.download();
  res.render('cdnconfig', {
    config: tactless.config(content.toString()).data,
    id: req.params.id,
  });
});

app.get('/ekey/:id', async (req, res) => {
  res.render('ekey', {
    id: req.params.id,
  });
});

app.get('/versions/:id', async (req, res) => {
  const file = bucket.file(`byobcdn/tactpoints/versions/${req.params.id}`);
  const [content] = await file.download();
  res.render('versions', {
    config: tactless.pipe(content.toString()).data[0],
    id: req.params.id,
  });
});

exports.function = app;
