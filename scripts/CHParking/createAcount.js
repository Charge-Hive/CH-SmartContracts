const {
  Client,
  ContractExecuteTransaction,
  ContractFunctionParameters,
  PrivateKey,
  AccountId,
  TokenAssociateTransaction,
} = require("@hashgraph/sdk");

const fs = require("fs");

require("dotenv").config({ path: "../.env" });

const adminAccountID = AccountId.fromString("0.0.5616371");
const adminPrivetKey = PrivateKey.fromStringECDSA(
  ""
);

const UserID = AccountId.fromString(process.env.OPERATOR_ID);
const UserPkey = PrivateKey.fromStringECDSA(process.env.OPERATOR_KEY);

const cParking = "0.0.5639419";
const NFTtoken = "0.0.5639407";

const userWallet = "0.0.5523459";
const metadata =
  "ipfs://bafkreiccs4d3aijz23y2fmhzsfzqejr2ontyz2yer6536olew3sfduprvi";

async function main() {
  const client = Client.forTestnet();

  client.setOperator(UserID, UserPkey);

  console.log("Associating NFT Token with User Wallet");
  const userTokenAssociateTx = await new TokenAssociateTransaction()
    .setAccountId(userWallet)
    .setTokenIds([NFTtoken])
    .execute(client);

  const userTokenAssociateReceipt = await userTokenAssociateTx.getReceipt(
    client
  );
  console.log(
    "User Token Association Status:",
    userTokenAssociateReceipt.status.toString()
  );

  console.log("Authorized Admins...");
  const adminTx = await new ContractExecuteTransaction()
    .setContractId(cParking)
    .setGas(100000)
    .setFunction(
      "addAdmin",
      new ContractFunctionParameters().addAddress(
        adminAccountID.toSolidityAddress()
      )
    )
    .execute(client);

  await adminTx.getReceipt(client);
  console.log("✅ Admin authorized!");

  client.setOperator(adminAccountID, adminPrivetKey);

  console.log("Creating Account...");

  const createAccountTx = new ContractExecuteTransaction()
    .setContractId(cParking)
    .setGas(500000)
    .setFunction(
      "createAccount",
      new ContractFunctionParameters()
        .addAddress(AccountId.fromString(userWallet).toSolidityAddress())
        .addString(userWallet)
        .addBytesArray([Buffer.from(metadata)])
    );

  const txResponse = await createAccountTx.execute(client);
  const receipt = await txResponse.getReceipt(client);

  console.log(`User account created with status: ${receipt.status}`);

  console.log("Creating Parking Session....");
  const startTime = Math.floor(Date.now() / 1000);
  const endTime = startTime + 2 * 60 * 60;
  const spotBookerWallet = "0.0.5616371";

  const createSessionTx = new ContractExecuteTransaction()
    .setContractId(cParking)
    .setGas(500000)
    .setFunction(
      "createParkingSession",
      new ContractFunctionParameters()
        .addUint256(startTime)
        .addUint256(endTime)
        .addAddress(AccountId.fromString(userWallet))
        .addAddress(AccountId.fromString(spotBookerWallet))
    );

  const txResponseCreate = await createSessionTx.execute(client);
  const receiptCreate = await txResponseCreate.getReceipt(client);
  const sessionId = receiptCreate.contractId;

  console.log(`Parking session created with ID: ${sessionId}`);

  const endSessionTx = new ContractExecuteTransaction()
    .setContractId(cParking)
    .setGas(500000)
    .setFunction(
      "endParkingSession",
      new ContractFunctionParameters().addUint256(sessionId)
    );

  const txResponseEnd = await endSessionTx.execute(client);
  const receiptEnd = await txResponseEnd.getReceipt(client);

  console.log(
    `Parking session ${sessionId} ended with status: ${receiptEnd.status}`
  );

  const distributRewardsTx = new ContractExecuteTransaction()
    .setContractId(cParking)
    .setGas(500000)
    .setFunction(
      "calculateAndDistributeRewards",
      new ContractFunctionParameters().addUint256(sessionId).addUint256(2)
    );

  const txResponseRewards = await distributRewardsTx.execute(client);
  const receiptRewards = await txResponseRewards.getReceipt(client);

  console.log(
    `Rewards distributed for session ${sessionId} with status: ${receiptRewards.status}`
  );
}

main();
