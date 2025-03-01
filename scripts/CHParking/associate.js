const {
  Client,
  PrivateKey,
  AccountId,
  TokenAssociateTransaction,
  Hbar,
} = require("@hashgraph/sdk");

require("dotenv").config({ path: "../.env" });

const operatorId = AccountId.fromString("0.0.5635651");
const operatorKey = PrivateKey.fromStringECDSA("");
const tokenId = "0.0.5630530";

async function main() {
  const client = Client.forTestnet();
  client.setOperator(operatorId, operatorKey);

  // Associate token with User Account
  const userTokenAssociateTx = await new TokenAssociateTransaction()
    .setAccountId(operatorId)
    .setTokenIds([tokenId])
    .execute(client);

  const userTokenAssociateReceipt = await userTokenAssociateTx.getReceipt(
    client
  );
  console.log(
    "User Token Association Status:",
    userTokenAssociateReceipt.status.toString()
  );
}

main();
