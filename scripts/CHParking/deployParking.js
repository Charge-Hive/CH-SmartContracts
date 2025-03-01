const {
  Client,
  ContractCreateFlow,
  ContractFunctionParameters,
  PrivateKey,
  AccountCreateTransaction,
  ContractExecuteTransaction,
  TransferTransaction,
  Hbar,
  AccountId,
} = require("@hashgraph/sdk");
const fs = require("fs");

require("dotenv").config({ path: "../.env" });

const operatorAccountId = AccountId.fromString(process.env.OPERATOR_ID);
const operatorPrivateKey = PrivateKey.fromStringECDSA(process.env.OPERATOR_KEY);

const contractNFT = "0.0.5639406";
const contractCHT = "0.0.5630529";

const contractBytecode = fs.readFileSync(
  "../contracts/parking/ParkingBinaries/CHParking_sol_CHParking.bin",
  "utf8"
);

async function deployContract() {
  const client = Client.forTestnet();
  client.setOperator(operatorAccountId, operatorPrivateKey);

  console.log(" Deploying CHParking contract...");
  const contractCreateTx = new ContractCreateFlow()
    .setBytecode(contractBytecode)
    .setConstructorParameters(
      new ContractFunctionParameters()
        .addAddress(AccountId.fromString(contractNFT).toSolidityAddress())
        .addAddress(AccountId.fromString(contractCHT).toSolidityAddress())
    )
    .setGas(500000); // Adjust gas as needed

  // Execute the contract creation transaction
  const submitTx = await contractCreateTx.execute(client);

  // Get the new contract ID
  const contractReceipt = await submitTx.getReceipt(client);
  const newContractId = contractReceipt.contractId;

  console.log(`Contract created successfully with ID: ${newContractId}`);

  const txTransfer = new TransferTransaction()
    .addHbarTransfer(operatorAccountId.toSolidityAddress(), new Hbar(-10))
    .addHbarTransfer(newContractId.toSolidityAddress(), new Hbar(10));

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

  console.log("🔑 Authorizing CHParking in the CHParkingNFT...");
  const nfttx = await new ContractExecuteTransaction()
    .setContractId(contractNFT)
    .setGas(100000)
    .setFunction(
      "authorizeContract",
      new ContractFunctionParameters().addAddress(
        newContractId.toSolidityAddress()
      )
    )
    .execute(client);

  await nfttx.getReceipt(client);
  console.log("✅ CHParking authorized in CHParkingNFT!");

  // console.log("Authorized Admins...");
  // const adminTx = await new ContractExecuteTransaction()
  //   .setContractId(newContractId)
  //   .setGas(100000)
  //   .setFunction(
  //     "addAdmin",
  //     new ContractFunctionParameters().addAddress(
  //       AccountId.fromString(manojAccount).toSolidityAddress()
  //     )
  //   )
  //   .execute(client);

  //   await adminTx.getReceipt(client);
  //   console.log("✅ Admin authorized!");
}

deployContract();
