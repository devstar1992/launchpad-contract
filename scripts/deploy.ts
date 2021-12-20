import hre, { ethers } from "hardhat";

(async () => {
  try {
    const [deployer] = await ethers.getSigners();
    console.log(`Deploying contract using :${deployer.address} account.`);
	const SAFEMATH = await hre.ethers.getContractFactory("SafeMath");
	const safemath = await SAFEMATH.deploy();
	console.log(`library deployed at: ${safemath.address}`);
    const IDO = await hre.ethers.getContractFactory("IDO", {
	  libraries: {
		SafeMath: safemath.address,
	  }});
    const ido = await IDO.deploy();

    console.log(`Contract deployed at: ${ido.address}`);

    process.exit(0);
  } catch (error) {
    console.error(error);
    process.exit(1);
  }
})();
