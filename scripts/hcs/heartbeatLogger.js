const {
  Client,
  TopicMessageSubmitTransaction,
  PrivateKey,
  AccountId
} = require("@hashgraph/sdk");
require("dotenv").config({ path: "../.env" });

const myAccountId = AccountId.fromString(process.env.OPERATOR_ID);
const myPrivateKey = PrivateKey.fromStringECDSA(process.env.OPERATOR_KEY);
const client = Client.forTestnet();
client.setOperator(myAccountId, myPrivateKey);

const heartbeatTopicId = "0.0.5640768";

async function sendHeartbeat(deviceId) {
  const heartbeat = {
    deviceId: deviceId,
    timestamp: Math.floor(Date.now() / 1000),
    status: "online",
    type: "heartbeat"
  };

  try {
    const response = await new TopicMessageSubmitTransaction({
      topicId: heartbeatTopicId,
      message: JSON.stringify(heartbeat),
    }).execute(client);

    console.log(`${new Date().toISOString()} - Heartbeat sent for ${deviceId}`);
  } catch (error) {
    console.error(
      `${new Date().toISOString()} - Error sending heartbeat:`,
      error
    );
  }
}

function startHeartbeatLogger(deviceId, intervalMinutes = 10) {
  console.log(
    `Starting heartbeat logger for ${deviceId} every ${intervalMinutes} minutes`
  );

  sendHeartbeat(deviceId);

  const intervalMs = intervalMinutes * 60 * 1000;
  const timer = setInterval(() => {
    sendHeartbeat(deviceId);
  }, intervalMs);

  return timer;
}

const deviceId = "galaxy-dragon-twilight";
const heartbeatLogger = startHeartbeatLogger(deviceId, 1);

// To stop the logger:
// clearInterval(heartbeatLogger);

console.log("Heartbeat logger is running. Press Ctrl+C to exit.");
