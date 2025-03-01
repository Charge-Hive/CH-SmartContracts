const {
  Client,
  PrivateKey,
  ContractCreateFlow,
  ContractFunctionParameters,
  ContractExecuteTransaction,
  ContractCallQuery,
  AccountId,
  TokenId,
  TransferTransaction,
  Hbar,
} = require("@hashgraph/sdk");
require("dotenv").config({ path: "../.env" });
const fs = require("fs");

const operatorId = AccountId.fromString(process.env.OPERATOR_ID);
const operatorKey = PrivateKey.fromStringECDSA(process.env.OPERATOR_KEY);
const tokenManagerAddress = "0.0.5630529";

const initialRewardRate = process.env.INITIAL_REWARD_RATE || 2;
const minimumKwh = process.env.MINIMUM_KWH || 1;
const initialPricePerKwhUsd = process.env.INITIAL_PRICE_PER_KWH_USD || 1;

async function main() {
  const client = Client.forTestnet();
  client.setOperator(operatorId, operatorKey);
  console.log(`👷 Using account: ${operatorId}`);
  console.log(`🔗 Using token manager: ${tokenManagerAddress}`);

  console.log("🚀 Starting deployment process...");

  console.log("🔍 Getting token address from CHTokenManager...");
  const tokenAddressQuery = await new ContractCallQuery()
    .setContractId(tokenManagerAddress)
    .setGas(100000)
    .setFunction("tokenAddress")
    .execute(client);

  // Decode the response to get the token address
  const tokenAddress = tokenAddressQuery.getAddress(0);
  console.log(`🪙 Found token at address: ${tokenAddress.toString()}`);
  const chTokenId = TokenId.fromSolidityAddress(tokenAddress);

  console.log("🔌 Deploying CHAdapter contract...");
  const chAdapterBytecode = fs.readFileSync(
    "../contracts/CH/AdapterBinaries/CHAdapter_sol_CHAdapter.bin",
    "utf8"
  );

  const chAdapterDeployTx = await new ContractCreateFlow()
    .setBytecode(chAdapterBytecode)
    .setGas(1000000)
    .setConstructorParameters(
      new ContractFunctionParameters()
        .addAddress(
          AccountId.fromString(tokenManagerAddress).toSolidityAddress()
        )
        .addInt64(initialRewardRate)
        .addInt64(minimumKwh)
        .addInt64(initialPricePerKwhUsd)
    )
    .execute(client);

  const chAdapterDeployReceipt = await chAdapterDeployTx.getReceipt(client);
  const chAdapterId = chAdapterDeployReceipt.contractId;
  console.log(`✅ CHAdapter contract deployed to: ${chAdapterId.toString()}`);

  const txTransfer = new TransferTransaction()
    .addHbarTransfer(operatorId.toSolidityAddress(), new Hbar(-10))
    .addHbarTransfer(
        chAdapterId.toSolidityAddress(),
      new Hbar(10)
    );

  const txTransferResponse = await txTransfer.execute(client);
  const receiptTransferTx = await txTransferResponse.getReceipt(client);
  const statusTransferTx = receiptTransferTx.status;
  const txIdTransfer = txTransferResponse.transactionId.toString();
  console.log(
    "-------------------------------- Transfer HBAR ------------------------------ "
  );
  console.log("- Receipt status           :", statusTransferTx.toString());
  console.log("- Transaction ID           :", txIdTransfer);
  console.log(
    "- Hashscan URL             :",
    `https://hashscan.io/testnet/tx/${txIdTransfer}`
  );

  console.log("🔑 Authorizing CHAdapter in the CHTokenManager...");
  const authorizeTx = await new ContractExecuteTransaction()
    .setContractId(tokenManagerAddress)
    .setGas(100000)
    .setFunction(
      "authorizeContract",
      new ContractFunctionParameters().addAddress(chAdapterId.toSolidityAddress())
    )
    .execute(client);

  await authorizeTx.getReceipt(client);
  console.log("✅ CHAdapter authorized in CHTokenManager!");

  console.log(`
🎉 Deployment completed successfully!

📄 Contract:
- CHAdapter: ${chAdapterId.toString()}

🔗 Integration:
- Using existing CHTokenManager: ${tokenManagerAddress}
- Token Address: ${tokenAddress.toString()}
    `);
}

main();
