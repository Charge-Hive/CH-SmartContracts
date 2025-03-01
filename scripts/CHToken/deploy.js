const {
  Client,
  PrivateKey,
  AccountId,
  ContractCreateFlow,
  ContractExecuteTransaction,
  ContractCallQuery,
  ContractFunctionParameters,
  Hbar,
  TokenAssociateTransaction,
  TransferTransaction,
} = require("@hashgraph/sdk");
require("dotenv").config({ path: "../.env" });
const fs = require("fs");

const operatorId = AccountId.fromString(process.env.OPERATOR_ID);
const operatorKey = PrivateKey.fromStringECDSA(process.env.OPERATOR_KEY);

async function main() {
  const client = Client.forTestnet();
  client.setOperator(operatorId, operatorKey);

  console.log(
    "===> Deploying the CustomTokenContract to Hedera using ContractCreateFlow"
  );

  contractBytecode = fs.readFileSync(
    "../contracts/CH/binaries/CHTokenManager_sol_CHTokenManager.bin",
    "utf8"
  );
  console.log("- Contract bytecode loaded");

  console.log("- Deploying contract...");
  const contractCreateFlow = new ContractCreateFlow()
    .setGas(4000000)
    .setBytecode(contractBytecode)
    .setConstructorParameters(new ContractFunctionParameters());

  const contractCreateSubmit = await contractCreateFlow.execute(client);
  const contractCreateRx = await contractCreateSubmit.getReceipt(client);
  const contractId = contractCreateRx.contractId;

  console.log(`- Contract created successfully with ID: ${contractId}`);
  console.log(`- Contract solidity address: ${contractId.toSolidityAddress()}`);

  const txTransfer = new TransferTransaction()
    .addHbarTransfer(operatorId.toSolidityAddress(), new Hbar(-10))
    .addHbarTransfer(contractId.toSolidityAddress(), new Hbar(10));

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

  console.log(
    "\n===> Creating the custom token with operator as admin/supply key"
  );
  const createTokenTx = new ContractExecuteTransaction()
    .setContractId(contractId)
    .setGas(1000000)
    .setFunction(
      "createToken",
      new ContractFunctionParameters().addAddress(
        operatorId.toSolidityAddress()
      )
    )
    .setPayableAmount(new Hbar(75))
    .freezeWith(client);

  const createTokenSubmit = await createTokenTx.execute(client);
  const createTokenRx = await createTokenSubmit.getReceipt(client);

  console.log(`- Token creation status: ${createTokenRx.status}`);

  console.log("\n===> Getting token information");
  const tokenAddressQuery = new ContractCallQuery()
    .setContractId(contractId)
    .setGas(100000)
    .setFunction("tokenAddress");

  const tokenAddressResult = await tokenAddressQuery.execute(client);
  const tokenAddress = tokenAddressResult.getAddress();

  console.log(`- Token address: ${tokenAddress}`);
}
main();
