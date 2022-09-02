import { HardhatRuntimeEnvironment } from "hardhat/types"
import { DeployFunction } from "hardhat-deploy/types"
import {
  networkConfig,
  developmentChains,
  QUORUM_PERCENTAGE,
  VOTING_PERIOD,
  VOTING_DELAY,
} from "../helper-hardhat-config"

const deployCryaGovernor: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  // @ts-ignore
  const { getNamedAccounts, deployments, network } = hre
  const { deploy, log, get } = deployments
  const { deployer } = await getNamedAccounts()
  const cryaToken = await get("CryaToken")
  const timeLock = await get("TimeLock")

  log("----------------------------------------------------")
  log("Deploying CryaGovernor and waiting for confirmations...")
  const governorContract = await deploy("CryaGovernor", {
    from: deployer,
    args: [
      cryaToken.address,
      timeLock.address,
      QUORUM_PERCENTAGE,
      VOTING_PERIOD,
      VOTING_DELAY,
    ],
    log: true,
    // we need to wait if on a live network so we can verify properly
    waitConfirmations: networkConfig[network.name].blockConfirmations || 1,
  })
  log(`CryaGovernor at ${governorContract.address}`)
}

export default deployCryaGovernor
deployCryaGovernor.tags = ["all", "cryagovernor"]