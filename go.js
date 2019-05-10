const crypto = require('crypto');
const Sequelize = require('sequelize');

const wait = mSec => new Promise(resolve => setTimeout(resolve, mSec));


// Connect to DB and verify authentication, resolve to a Sequelize instance
// Or, reject with SequelizeConnectionError (timeout), SequelizeAccessDeniedError (credentials), etc
const connect = async () => {
  const sequelize = new Sequelize(
    process.env.MYSQL_DATABASE,
    process.env.MYSQL_USER,
    process.env.MYSQL_PASSWORD,
    {
      port: process.env.MYSQL_PORT,
      dialect: 'mysql'
    },
  );
  // authenticate() will throw "SequelizeConnectionError: connect ETIMEDOUT" if DB is not reachable
  await sequelize.authenticate();
  return sequelize;
};

// Repeatedly attempt to connect; exposes final attempt success or failure
const waitConnect = async (delayMsec, timeoutMsec) => {
  const endTime = Date.now() + timeoutMsec;
  delayMsec = delayMsec > 1000 ? delayMsec : 1000;
  while( Date.now() <= endTime ) {
    try {
      await wait(delayMsec);
      await connect().then(sequelize => sequelize.close());
      break
    }
    catch (err) {
      console.log('sequelize: failed connect attempt:', err + '');
    }
  }
  // resolve or reject based on this call to connect()
  const sequelize = await connect();
  return sequelize;
};

// Return a Sequelize model configuration
const tableOptions = Sequelize => ({
  documentIdentifier: {
    allowNull: false,
    primaryKey: true,
    type: Sequelize.STRING,
  },
  documentBlob: {
    allowNull: false,
    type: Sequelize.BLOB('long'),
  },
  createdAt: {
    allowNull: false,
    defaultValue: Sequelize.NOW,
    type: Sequelize.DATE,
  },
  updatedAt: {
    allowNull: false,
    defaultValue: Sequelize.NOW,
    type: Sequelize.DATE,
  },
});


// Attempt to break the Docker engine daemon
const main = async () => {
  console.log('go.js main(): starting');

  // get the blob, synchronously
  const fileName = process.argv[2];
  console.log('fileName:', fileName)
  const documentBlob = require('fs').readFileSync(fileName);
  const documentIdentifier = crypto.createHash('sha256').update(documentBlob).digest('hex');
  const sizeBytes = documentBlob.length;
  console.log('blob:', JSON.stringify({ documentIdentifier, sizeBytes }));

  // connect to DB: try once every 3 seconds for up to 60 seconds
  const sequelize = await waitConnect(3000, 60000);
  console.log('sequelize: connected to DB');

  // make the table in the DB
  await sequelize.queryInterface.createTable('AttachmentBlobs', tableOptions(Sequelize));
  console.log('sequelize: created table');

  // make the Sequelize model
  const AttachmentBlob = sequelize.define('AttachmentBlob', tableOptions(Sequelize));
  console.log('sequelize: created model');

  const maxMessage = 512;
  const logging = message => console.log('AttachmentBlob:', message.substring(0, maxMessage), message.length > maxMessage ? `... for ${message.length - maxMessage} more characters` : '');

  // attempt to break the Docker engine
  const [item, created] = await AttachmentBlob.findOrCreate({ where: { documentIdentifier, documentBlob }, logging });
  // if we get here, the attempt to break things failed
  console.log('created:', created, item.documentBlob.length, item.documentIdentifier);

  console.log('go.js main(): returning');
  return;
};


// make it all happen
main()
  .then(() => {
    console.log('failed to find trouble: oh well');
    process.exit(0);
  })
  .catch(err => {
    console.log('succeeded to find trouble:', err+'');
    process.exit(1);
  });
