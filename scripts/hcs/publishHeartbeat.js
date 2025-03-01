const {
  Client,
  TopicMessageSubmitTransaction,
  PrivateKey,
  AccountId,
} = require("@hashgraph/sdk");

require("dotenv").config({ path: "../.env" });

const operatorId = AccountId.fromString(process.env.OPERATOR_ID);
const operatorKey = PrivateKey.fromStringECDSA(process.env.OPERATOR_KEY);

const heartbeatsTopicId = "0.0.5640768";

async function publishHeartbeat() {
  const client = Client.forTestnet();
  client.setOperator(operatorId, operatorKey);

  const heartbeat = {
    type: "heartbeat",
    deviceId: "galaxy-dragon-twilight",
    timestamp: Math.floor(Date.now() / 1000),
    status: "online",
  };

  const response = await new TopicMessageSubmitTransaction({
    topicId: heartbeatsTopicId,
    message: JSON.stringify(heartbeat),
  }).execute(client);

  const receipt = await response.getReceipt(client);
  console.log(
    `Heartbeat sent for galaxy-dragon-twilight: sequence #${receipt.topicSequenceNumber}`
  );
}

publishHeartbeat();
