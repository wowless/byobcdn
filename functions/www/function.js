const datastore = new (require('@google-cloud/datastore').Datastore)();

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

app.get('/a/:id', async (req, res) => {
  const [entities] = await datastore
    .createQuery('ArchiveEntry')
    .filter('archive', req.params.id)
    .limit(50)
    .run();
  res.render('archive', {
    archiveEntries: entities,
    id: req.params.id,
  });
});

app.get('/e/:id', async (req, res) => {
  const [entities] = await datastore
    .createQuery('ArchiveEntry')
    .filter('ekey', req.params.id)
    .limit(50)
    .run();
  res.render('ekey', {
    archiveEntries: entities,
    id: req.params.id,
  });
});

exports.function = app;
