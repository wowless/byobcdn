const datastore = new (require('@google-cloud/datastore').Datastore)();

const app = require('express')();
app.set('view engine', 'pug');
app.engine('pug', require('pug').__express);

app.get('/', (_, res) => {
  res.render('index');
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
