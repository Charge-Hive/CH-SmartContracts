const {
  Client,
  ContractExecuteTransaction,
  ContractFunctionParameters,
  PrivateKey,
  AccountId,
  TokenAssociateTransaction,
  ContractCallQuery,
} = require("@hashgraph/sdk");

const fs = require("fs");

require("dotenv").config({ path: "../.env" });

const adminAccountID = AccountId.fromString("0.0.5639900");
const adminPrivetKey = PrivateKey.fromStringECDSA(
  "3030020100300706052b8104000a042204208088f8cc9bc60929e6f2ff8fc867a31d64c38bc424c068361646ac7ea7a320df"
);

const UserID = AccountId.fromString(process.env.OPERATOR_ID);
const UserPkey = PrivateKey.fromStringECDSA(process.env.OPERATOR_KEY);

const cParking = "0.0.5639942";
const CHTToken = "0.0.5630530";

const userWallet = "0.0.5616372";

async function main() {
  const client = Client.forTestnet();

  //   client.setOperator(UserID, UserPkey);
  //     console.log("Authorized Admins...");
  //     const adminTx = await new ContractExecuteTransaction()
  //       .setContractId(cParking)
  //       .setGas(100000)
  //       .setFunction(
  //         "addAdmin",
  //         new ContractFunctionParameters().addAddress(
  //           adminAccountID.toSolidityAddress()
  //         )
  //       )
  //       .execute(client);

  //     await adminTx.getReceipt(client);
  //     console.log("✅ Admin authorized!");

  client.setOperator(adminAccountID, adminPrivetKey);

  console.log("Creating Account...");

  const createAccountTx = new ContractExecuteTransaction()
    .setContractId(cParking)
    .setGas(500000)
    .setFunction(
      "createAccount",
      new ContractFunctionParameters()
        .addAddress(AccountId.fromString(userWallet).toSolidityAddress())
        .addString("1")
        .addString(userWallet)
    );

  const txResponse = await createAccountTx.execute(client);
  const receipt = await txResponse.getReceipt(client);

  console.log(`User account created with status: ${receipt.status}`);

  const adapterInfoQuery = new ContractCallQuery()
    .setContractId(cParking)
    .setGas(600000)
    .setFunction(
      "isUserRegistered",
      new ContractFunctionParameters().addAddress(
        AccountId.fromString(userWallet).toSolidityAddress()
      )
    );

  const adapterInfoResult = await adapterInfoQuery.execute(client);
  const DID = adapterInfoResult.getBool(1);
  console.log(`isUserRegistered - ${DID}`);

  console.log("Creating Parking Session....");
  const startTime = Math.floor(Date.now() / 1000) + 3600;
  const endTime = startTime + 2 * 60 * 60;
  const spotBookerWallet = "0.0.5616371";

  const startSessionTx = await new ContractExecuteTransaction()
    .setContractId(cParking)
    .setGas(500000)
    .setFunction(
      "createParkingSession",
      new ContractFunctionParameters()
        .addInt64(startTime)
        .addInt64(endTime)
        .addAddress(AccountId.fromString(userWallet).toSolidityAddress())
        .addAddress(AccountId.fromString(spotBookerWallet).toSolidityAddress())
    )
    .execute(client);

  const startSessionReceipt = await startSessionTx.getReceipt(client);
  console.log("Session Start Status:", startSessionReceipt.status.toString());

  //   // Retrieve the session ID
  const startSessionRecord = await startSessionTx.getRecord(client);
  const sessionId = startSessionRecord.contractFunctionResult
    .getUint256(0)
    .toString();
  console.log("Generated Session ID:", sessionId);

  console.log(`Parking session created with ID: ${sessionId}`);

  const endSessionTx = new ContractExecuteTransaction()
    .setContractId(cParking)
    .setGas(500000)
    .setFunction(
      "endParkingSession",
      new ContractFunctionParameters().addUint256(sessionId).addInt64(1)
    );

  const txResponseEnd = await endSessionTx.execute(client);
  const receiptEnd = await txResponseEnd.getReceipt(client);

  console.log(
    `Parking session ${sessionId} ended with status: ${receiptEnd.status}`
  );

  const transaction = new ContractExecuteTransaction()
    .setContractId(cParking)
    .setGas(900000)
    .setFunction(
      "distributeRewards",
      new ContractFunctionParameters().addUint256(sessionId)
    );

  const txResponsee = await transaction.execute(client);
  const receiptt = await txResponsee.getReceipt(client);
  const record = await txResponsee.getRecord(client);
  const success = record.contractFunctionResult.getBool(0);

  console.log(`\n✅ Rewards distributed successfully!`);
  console.log(
    `- ${sessionDetails.calculatedReward} tokens sent to ${sessionDetails.userWallet}`
  );
  console.log(`\n- Transaction ID: ${txResponse.transactionId.toString()}`);
  console.log(
    `- Hashscan URL: https://hashscan.io/testnet/tx/${txResponse.transactionId.toString()}`
  );
}

main();
