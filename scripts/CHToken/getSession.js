const {
  Client,
  PrivateKey,
  AccountId,
  ContractCallQuery,
  ContractFunctionParameters,
} = require("@hashgraph/sdk");

require("dotenv").config({ path: "../.env" });

const adapterId = AccountId.fromString("0.0.5635651");
const userWalletAddress = AccountId.fromString("0.0.5635652");
const adapterKey = PrivateKey.fromStringECDSA(
  ""
);
const chAdapterContractId = "0.0.5635646";

const sessionId =
  "3670f0eabc080f5b4aebea997fc6dde510f7feb26f05376d088186c54512a76b";

async function main() {
  const client = Client.forTestnet();
  client.setOperator(adapterId, adapterKey);

  const contractCallTx = new ContractCallQuery()
    .setContractId(chAdapterContractId)
    .setGas(500000)
    .setFunction(
      "getSessionDetails",
      new ContractFunctionParameters().addString(sessionId)
    );

  const contractCallResult = await contractCallTx.execute(client);
  const sessionDetails = {
    sessionIdOut: contractCallResult.getString(0),
    startTimestamp: contractCallResult.getUint256(1),
    endTimestamp: contractCallResult.getUint256(2),
    energyUsed: contractCallResult.getInt64(3),
    multiplier: contractCallResult.getInt64(4),
    calculatedReward: contractCallResult.getInt64(5),
    calculatedUSD: contractCallResult.getInt64(6),
    active: contractCallResult.getBool(7),
    tokenDistributed: contractCallResult.getBool(8),
    userWallet: contractCallResult.getAddress(9),
    adapterAddress: contractCallResult.getAddress(10),
  };
  console.log("Session Details:");
  console.log("----------------");
  console.log(`Session ID: ${sessionDetails.sessionIdOut}`);
  console.log(
    `Start Timestamp: ${new Date(
      Number(sessionDetails.startTimestamp) * 1000
    ).toISOString()}`
  );
  console.log(
    `End Timestamp: ${
      sessionDetails.endTimestamp > 0
        ? new Date(Number(sessionDetails.endTimestamp) * 1000).toISOString()
        : "Active"
    }`
  );
  console.log(`Energy Used: ${sessionDetails.energyUsed.toString()}`);
  console.log(`Multiplier: ${sessionDetails.multiplier.toString()}`);
  console.log(
    `Calculated Reward: ${sessionDetails.calculatedReward.toString()}`
  );
  console.log(`Calculated USD: ${sessionDetails.calculatedUSD.toString()}`);
  console.log(`Active: ${sessionDetails.active}`);
  console.log(`Token Distributed: ${sessionDetails.tokenDistributed}`);

  const userCallTx = new ContractCallQuery()
    .setContractId(chAdapterContractId)
    .setGas(500000)
    .setFunction(
      "getAdapterByUser",
      new ContractFunctionParameters().addAddress(
        userWalletAddress.toSolidityAddress()
      )
    );

  const userCallResult = await userCallTx.execute(client);
  const adpAddress = userCallResult.getAddress(0);
  console.log("Adapter Address - ", adpAddress);
}

main();
