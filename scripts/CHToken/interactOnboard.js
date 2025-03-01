const {
  Client,
  PrivateKey,
  AccountId,
  ContractExecuteTransaction,
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
      "completeRegistration",
      new ContractFunctionParameters()
        .addAddress(userWalletAddress.toSolidityAddress())
        .addString("Adapter Onboarding")
    )
    .execute(client);

  const completeRegReceipt = await completeRegTx.getReceipt(client);
  console.log(`Transaction status: ${completeRegReceipt.status.toString()}`);
  console.log("✅ Registration completed successfully!");

  const adapterInfoQuery = new ContractCallQuery()
    .setContractId(chAdapterContractId)
    .setGas(600000)
    .setFunction(
      "getAdapterInfo",
      new ContractFunctionParameters().addAddress(adapterId.toSolidityAddress())
    );

  const adapterInfoResult = await adapterInfoQuery.execute(client);
  const DID = adapterInfoResult.getString(1);
  console.log(`DID - ${DID}`);

  console.log(`💎 Setting NFT ID to: ${nftId}`);
  const setNftTx = await new ContractExecuteTransaction()
    .setContractId(chAdapterContractId)
    .setGas(500000)
    .setFunction(
      "setAdapterNFT",
      new ContractFunctionParameters().addString(nftId)
    )
    .execute(client);

  await setNftTx.getReceipt(client);
  console.log("✅ NFT ID set successfully!");
  console.log(
    "\n🎉 Adapter setup complete! The adapter is now ready to start charging sessions.");
}

main();
