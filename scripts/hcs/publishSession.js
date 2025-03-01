const {
  Client,
  TopicMessageSubmitTransaction,
  PrivateKey,
  AccountId,
} = require("@hashgraph/sdk");

require("dotenv").config({ path: "../.env" });

const operatorId = AccountId.fromString(process.env.OPERATOR_ID);
const operatorKey = PrivateKey.fromStringECDSA(process.env.OPERATOR_KEY);

const sessionsTopicId = "0.0.5640769";

async function publishSession() {
  const client = Client.forTestnet();
  client.setOperator(operatorId, operatorKey);

  const session = {
    device: "galaxy-dragon-twilight",
    TotalKWh: 15,
    energyValues: [
      {
        energy: 0,
        timestamp: 1740825411,
      },
      {
        energy: 1,
        timestamp: 1740825412,
      },
      {
        energy: 2,
        timestamp: 1740825413,
      },
      {
        energy: 3,
        timestamp: 1740825414,
      },
      {
        energy: 4,
        timestamp: 1740825415,
      },
      {
        energy: 5,
        timestamp: 1740825416,
      },
      {
        energy: 6,
        timestamp: 1740825417,
      },
      {
        energy: 7,
        timestamp: 1740825418,
      },
      {
        energy: 8,
        timestamp: 1740825419,
      },
      {
        energy: 9,
        timestamp: 1740825420,
      },
      {
        energy: 10,
        timestamp: 1740825421,
      },
      {
        energy: 11,
        timestamp: 1740825422,
      },
      {
        energy: 12,
        timestamp: 1740825423,
      },
      {
        energy: 13,
        timestamp: 1740825424,
      },
      {
        energy: 14,
        timestamp: 1740825425,
      },
    ],
  };

  const response = await new TopicMessageSubmitTransaction({
    topicId: sessionsTopicId,
    message: JSON.stringify(session),
  }).execute(client);

  const receipt = await response.getReceipt(client);
  console.log(
    `Session published for galaxy-dragon-twilight: sequence #${receipt.topicSequenceNumber}`
  );
}

publishSession();
