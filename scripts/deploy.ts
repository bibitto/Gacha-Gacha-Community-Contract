import { ethers } from "hardhat";

async function main() {
    // GachaPon.sol
    const GachaPon = await ethers.getContractFactory("GachaPon");
    const gachaPon = await GachaPon.deploy();
    await gachaPon.deployed();
    console.log("gachaPon address: ", gachaPon.address);

    // GachaMintExtension.sol
    const slashMintFee = 30; // usd
    const GachaMintExtension = await ethers.getContractFactory("GachaMintExtension");
    const gachaMintExtension = await GachaMintExtension.deploy(gachaPon.address, slashMintFee);
    await gachaMintExtension.deployed();
    console.log("gachaMintExtension address: ", gachaMintExtension.address);

    // GachaPaymentExtension.sol
    const commissionReceiver = gachaPon.owner();
    const commissionPercentage = 2; // %
    const GachaPaymentExtension = await ethers.getContractFactory("GachaPaymentExtension");
    const gachaPaymentExtension = await GachaPaymentExtension.deploy(
        gachaPon.address,
        commissionReceiver,
        commissionPercentage
    );
    await gachaPaymentExtension.deployed();
    console.log("gachaPaymentExtension address: ", gachaPaymentExtension.address);

    // register the slash mint extension to GachaPon
    await gachaPon.updateSlashMintExtension(gachaMintExtension.address);

    // mint community gacha NFT
    const gachaFee = 1; // usd
    const tokenURI = "";
    await gachaPon.mint(gachaPon.owner(), tokenURI, gachaFee);
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
