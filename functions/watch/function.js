const {CloudTasksClient} = require('@google-cloud/tasks');
const taskclient = new CloudTasksClient();

exports.watch = async (event, _) => {
  const body = {
    bucket: event.bucket,
    name: event.name,
  };
  await taskclient.createTask({
    parent: process.env.BYOBCDN_PROCESS_QUEUE,
    task: {
      httpRequest: {
        body: Buffer.from(JSON.stringify(body)).toString('base64'),
        headers: {
          'Content-Type': 'application/json',
        },
        httpMethod: 'POST',
        oidcToken: {
          serviceAccountEmail: process.env.BYOBCDN_PROCESS_INVOKER,
        },
        url: process.env.BYOBCDN_PROCESS_ENDPOINT,
      },
    },
  });
};
