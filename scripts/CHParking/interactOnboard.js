const {
  Client,
  PrivateKey,
  AccountId,
  ContractExecuteTransaction,
  ContractCallQuery,
  ContractFunctionParameters,
} = require("@hashgraph/sdk");

require("dotenv").config({ path: "../.env" });

const adapterId = AccountId.fromString("0.0.5640055");
const userWalletAddress = AccountId.fromString("0.0.5640056");
const adapterKey = PrivateKey.fromStringECDSA(
  ""
);
const chAdapterContractId = "0.0.5640053";
const nftId = "jdncjlrnnclkernmlnerflnelfkmlkerjfknejfn";

async function main() {
  const client = Client.forTestnet();
  client.setOperator(adapterId, adapterKey);
  console.log(`🔌 Adapter operating from: ${adapterId}`);

  console.log("🔑 Completing adapter registration...");
  console.log(`   User wallet: ${userWalletAddress}`);

  const completeRegTx = await new ContractExecuteTransaction()
    .setContractId(chAdapterContractId)
    .setGas(500000)
    .setFunction(
      "createAccount",
      new ContractFunctionParameters()
        .addAddress(userWalletAddress.toSolidityAddress())
        .addString("1")
        .addString(userWalletAddress.toString())
    )
    .execute(client);

  const completeRegReceipt = await completeRegTx.getReceipt(client);
  console.log(`Transaction status: ${completeRegReceipt.status.toString()}`);
  console.log("✅ Registration completed successfully!");

  const adapterInfoQuery = new ContractCallQuery()
    .setContractId(chAdapterContractId)
    .setGas(600000)
    .setFunction(
      "isUserRegistered",
      new ContractFunctionParameters().addAddress(userWalletAddress.toSolidityAddress())
    );

  const adapterInfoResult = await adapterInfoQuery.execute(client);
  const DID = adapterInfoResult.getBool(1);
  console.log(`User Registration - ${DID}`);
}

main();
