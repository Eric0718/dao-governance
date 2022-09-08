import { HardhatRuntimeEnvironment } from "hardhat/types"
import { DeployFunction } from "hardhat-deploy/types"
import { networkConfig, developmentChains } from "../helper-hardhat-config"
//@ts-ignore
import { ethers } from "hardhat"

const deployBusiness: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  // @ts-ignore
  const { getNamedAccounts, deployments, network } = hre
  const { deploy, log } = deployments
  const { deployer } = await getNamedAccounts()
  log("----------------------------------------------------")
  log("Deploying Business and waiting for confirmations...")
  const business = await deploy("Business", {
    from: deployer,
    args: [],
    log: true,
    // we need to wait if on a live network so we can verify properly
    waitConfirmations: networkConfig[network.name].blockConfirmations || 1,
  })
  log(`Business at ${business.address}`)
  
  const businessContract = await ethers.getContractAt("Business", business.address)
  const timeLock = await ethers.getContract("TimeLock")
  const transferTx = await businessContract.transferOwnership(timeLock.address)
  await transferTx.wait(1)
  log("OwnerShip transfered,ALL DONE!")
}

export default deployBusiness
deployBusiness.tags = ["all", "business"]