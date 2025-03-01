const {
  Client,
  PrivateKey,
  AccountId,
  ContractExecuteTransaction,
  ContractCallQuery,
  AccountCreateTransaction,
  ContractFunctionParameters,
  TokenAssociateTransaction,
  Hbar,
} = require("@hashgraph/sdk");

require("dotenv").config({ path: "../.env" });

const adapterAccountId = AccountId.fromString("0.0.5635651");
const userAccountId = AccountId.fromString("0.0.5638502");
const operatorKey = PrivateKey.fromStringECDSA(
  ""
);
const contractId = "0.0.5635646";

async function main() {
  const client = Client.forTestnet();
  client.setOperator(adapterAccountId, operatorKey);

  const startSessionTx = await new ContractExecuteTransaction()
      .setContractId(contractId)
      .setGas(500000)
      .setFunction(
        "startSession", 
        new ContractFunctionParameters()
          .addAddress(userAccountId.toSolidityAddress())
          .addString("Test Location")
      )
      .execute(client);

    const startSessionReceipt = await startSessionTx.getReceipt(client);
    console.log("Session Start Status:", startSessionReceipt.status.toString());

    // Retrieve the session ID 
    const startSessionRecord = await startSessionTx.getRecord(client);
    const sessionId = startSessionRecord.contractFunctionResult.getString(0);
    console.log("Generated Session ID:", sessionId);

    // End Session
    const endSessionTx = await new ContractExecuteTransaction()
      .setContractId(contractId)
      .setGas(500000)
      .setFunction(
        "endSession", 
        new ContractFunctionParameters()
          .addString(sessionId)
          .addInt64(20)
          .addInt64(1)
      )
      .execute(client);

    const endSessionReceipt = await endSessionTx.getReceipt(client);
    console.log("Session End Status:", endSessionReceipt.status.toString());

    // 6. Distribute Rewards
    const distributeRewardsTx = await new ContractExecuteTransaction()
      .setContractId(contractId)
      .setGas(500000)
      .setFunction(
        "distributeRewards", 
        new ContractFunctionParameters()
          .addString(sessionId)
      )
      .execute(client);

    const distributeRewardsReceipt = await distributeRewardsTx.getReceipt(client);
    console.log("Rewards Distribution Status:", distributeRewardsReceipt.status.toString());
}

main();