const {
  Client,
  PrivateKey,
  ContractCreateFlow,
  ContractFunctionParameters,
  Hbar,
  AccountId,
  ContractExecuteTransaction,
  ContractCallQuery,
} = require("@hashgraph/sdk");
const fs = require("fs");
require("dotenv").config({ path: "../.env" });

const operatorAccountId = AccountId.fromString(process.env.OPERATOR_ID);
const operatorPrivateKey = PrivateKey.fromStringECDSA(process.env.OPERATOR_KEY);
contractBytecode = fs.readFileSync(
  "../contracts/parking/Binaries/CHParkNFT_sol_CHParkNFT.bin",
  "utf8"
);

async function deployNFTContract() {
  const client = Client.forTestnet();
  client.setOperator(operatorAccountId, operatorPrivateKey);

  console.log(
    `Deploying CHParkNFT contract using account: ${operatorAccountId}`
  );

  const contractCreate = new ContractCreateFlow()
    .setGas(4000000)
    .setBytecode(contractBytecode)
    .setConstructorParameters(new ContractFunctionParameters());

  const contractCreateTx = await contractCreate.execute(client);

  const contractCreateReceipt = await contractCreateTx.getReceipt(client);

  const contractId = contractCreateReceipt.contractId;
  const contractAddress = contractId.toSolidityAddress();

  console.log(`Contract deployed successfully! Contract ID: ${contractId}`);
  console.log(`Contract EVM address: ${contractAddress}`);

  const deploymentInfo = {
    contractId: contractId.toString(),
    contractAddress: contractAddress,
    timestamp: new Date().toISOString(),
  };

  fs.writeFileSync(
    "./deployment-info.json",
    JSON.stringify(deploymentInfo, null, 2)
  );

  console.log("Deployment information saved to deployment-info.json");

  console.log("Creating the ChargeHive NFT collection...");
  const autoRenewPeriod = 7890000;

  const createCollectionTx = new ContractExecuteTransaction()
    .setContractId(contractId)
    .setGas(1000000)
    .setFunction(
      "createChargeHiveCollection",
      new ContractFunctionParameters().addInt64(autoRenewPeriod).addAddress(operatorAccountId.toSolidityAddress())
    )
    .setPayableAmount(new Hbar(10));

  const createCollectionSubmit = await createCollectionTx.execute(client);
  const createCollectionReceipt = await createCollectionSubmit.getReceipt(
    client
  );

  console.log(
    `NFT Collection created. Status: ${createCollectionReceipt.status}`
  );

  const tokenAddressQuery = new ContractCallQuery()
    .setContractId(contractId)
    .setGas(100000)
    .setFunction("getCollectionAddress");

  const tokenAddressResult = await tokenAddressQuery.execute(client);
  const tokenAddress = tokenAddressResult.getAddress();

  console.log(`ChargeHive NFT collection address: ${tokenAddress}`);

  deploymentInfo.tokenAddress = tokenAddress;
  fs.writeFileSync(
    "./deployment-info.json",
    JSON.stringify(deploymentInfo, null, 2)
  );

  console.log("Updated deployment information with token address");
}

deployNFTContract();
