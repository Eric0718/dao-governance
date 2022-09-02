import { HardhatRuntimeEnvironment } from "hardhat/types"
import { DeployFunction } from "hardhat-deploy/types"
import verify from "../helper-functions"
import { networkConfig, developmentChains } from "../helper-hardhat-config"
// @ts-ignore
import { ethers } from "hardhat"

const deployCryaToken: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  // @ts-ignore
  const { getNamedAccounts, deployments, network } = hre
  const { deploy, log } = deployments
  const { deployer } = await getNamedAccounts()
  log("----------------------------------------------------")
  log("Deploying CryaToken and waiting for confirmations...")
  const CryaToken = await deploy("CryaToken", {
    from: deployer,
    args: [],
    log: true,
    // we need to wait if on a live network so we can verify properly
    waitConfirmations: networkConfig[network.name].blockConfirmations || 1,
  })
  log(`CryaToken at ${CryaToken.address}`)
  log(`Delegating to ${deployer}`)
  await delegate(CryaToken.address, deployer)
  log("Delegated!")
}

const delegate = async (CryaTokenAddress: string, delegatedAccount: string) => {
  const CryaToken = await ethers.getContractAt("CryaToken", CryaTokenAddress)
  const transactionResponse = await CryaToken.delegate(delegatedAccount)
  await transactionResponse.wait(1)
  console.log(`Checkpoints: ${await CryaToken.numCheckpoints(delegatedAccount)}`)
}

export default deployCryaToken
deployCryaToken.tags = ["all", "cryatoken"]