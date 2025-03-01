const {
  Client,
  TopicCreateTransaction,
  TopicMessageSubmitTransaction,
  PrivateKey,
  AccountId,
} = require("@hashgraph/sdk");

require("dotenv").config({ path: "../.env" });

const operatorId = AccountId.fromString(process.env.OPERATOR_ID);
const operatorKey = PrivateKey.fromStringECDSA(process.env.OPERATOR_KEY);

async function setupCHTopics() {
  const client = Client.forTestnet();
  client.setOperator(operatorId, operatorKey);

  const heartbeatsTx = await new TopicCreateTransaction()
    .setTopicMemo("ChargeHive Network EV Chargers Heartbeats")
    .execute(client);
  
  const heartbeatsReceipt = await heartbeatsTx.getReceipt(client);
  const heartbeatsTopicId = heartbeatsReceipt.topicId;
  
  console.log("HeartBeat Topic ID - ", heartbeatsTopicId )


  const sessionsTx = await new TopicCreateTransaction()
    .setTopicMemo("ChargeHive EV Charging Session Data")
    .execute(client);
  
  const sessionsReceipt = await sessionsTx.getReceipt(client);
  const sessionsTopicId = sessionsReceipt.topicId;
  
  console.log(`Session Data Topic - ${sessionsTopicId}`);

}

setupCHTopics()