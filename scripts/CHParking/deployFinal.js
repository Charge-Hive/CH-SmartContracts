const {
  Client,
  ContractCreateFlow,
  ContractFunctionParameters,
  PrivateKey,
  ContractExecuteTransaction,
  TransferTransaction,
  Hbar,
  AccountId,
} = require("@hashgraph/sdk");
const fs = require("fs");

require("dotenv").config({ path: "../.env" });

const operatorAccountId = AccountId.fromString(process.env.OPERATOR_ID);
const operatorPrivateKey = PrivateKey.fromStringECDSA(process.env.OPERATOR_KEY);

const contractCHT = "0.0.5630529";

const manojAccount = "0.0.5530044";


const contractBytecode = fs.readFileSync(
  "../contracts/parking/FinalParkingBinaries/FinalParking_sol_CHParking.bin",
  "utf8"
);

async function deployContract() {
  const client = Client.forTestnet();
  client.setOperator(operatorAccountId, operatorPrivateKey);

  console.log(" Deploying CHParking contract...");

  const initialRewardRate = 1;
  const initialPricePerMinute = 15;

  const contractCreateTx = new ContractCreateFlow()
    .setBytecode(contractBytecode)
    .setConstructorParameters(
      new ContractFunctionParameters()
        .addAddress(AccountId.fromString(contractCHT).toSolidityAddress())
        .addInt64(initialRewardRate)
        .addInt64(initialPricePerMinute)
    )
    .setGas(500000);

  const submitTx = await contractCreateTx.execute(client);

  const contractReceipt = await submitTx.getReceipt(client);
  const newContractId = contractReceipt.contractId;

  console.log(`Contract created successfully with ID: ${newContractId}`);
  console.log(`- Initial reward rate: ${initialRewardRate} tokens per minute`);
  console.log(`- Initial price: $${initialPricePerMinute / 10} per minute`);

  const txTransfer = new TransferTransaction()
    .addHbarTransfer(operatorAccountId.toString(), new Hbar(-10))
    .addHbarTransfer(newContractId.toString(), new Hbar(10));

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

  console.log("🔄 Associating CHParking with the token...");
  const associateTx = await new ContractExecuteTransaction()
    .setContractId(newContractId)
    .setGas(100000)
    .setFunction("associateWithToken")
    .execute(client);

  const associateReceipt = await associateTx.getReceipt(client);
  console.log(
    "✅ Token association status:",
    associateReceipt.status.toString()
  );

  console.log("🔑 Authorizing CHParking in the CHTokenManager...");
  const authorizeTx = await new ContractExecuteTransaction()
    .setContractId(contractCHT)
    .setGas(100000)
    .setFunction(
      "authorizeContract",
      new ContractFunctionParameters().addAddress(
        newContractId.toSolidityAddress()
      )
    )
    .execute(client);

  await authorizeTx.getReceipt(client);
  console.log("✅ CHParking authorized in CHTokenManager!");

  // Add admin to the contract
  console.log("👤 Adding admin to the contract...");
  const adminTx = await new ContractExecuteTransaction()
    .setContractId(newContractId)
    .setGas(100000)
    .setFunction(
      "addAdmin",
      new ContractFunctionParameters().addAddress(
        AccountId.fromString(manojAccount).toSolidityAddress()
      )
    )
    .execute(client);

  await adminTx.getReceipt(client);
  console.log(`✅ Admin authorized: ${manojAccount}`);

  console.log("\n🎉 Deployment complete! Contract ready to use.");
  console.log(`Contract ID: ${newContractId}`);
  console.log(
    `Hashscan URL: https://hashscan.io/testnet/contract/${newContractId}`
  );

  return newContractId;
}

deployContract()
  .then((contractId) => {
    console.log("Deployment successful!");
  })
  .catch((error) => {
    console.error("Deployment failed:", error);
    process.exit(1);
  });
