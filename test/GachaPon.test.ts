import { Contract, utils } from "ethers";
import { assert, expect } from "chai";
import { ethers } from "hardhat";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";

const testMetadata = "ipfs/....1";

describe("GachaPon", function () {
    async function deployFixture() {
        const [owner, addr1, addr2, addr3] = await ethers.getSigners();

        const GachaPon = await ethers.getContractFactory("GachaPon");
        const gachaPon = await GachaPon.deploy();

        const mintFee = 30; // usd
        const GachaMintExtension = await ethers.getContractFactory("GachaMintExtension");
        const gachaMintExtension = await GachaMintExtension.deploy(gachaPon.address, mintFee);

        const commissionReceiver = owner.address;
        const commissionPercentage = 2; // %
        const GachaPaymentExtension = await ethers.getContractFactory("GachaPaymentExtension");
        const gachaPaymentExtension = await GachaPaymentExtension.deploy(
            gachaPon.address,
            commissionReceiver,
            commissionPercentage
        );

        const TestNFT = await ethers.getContractFactory("TestNFT");
        const testNft = await TestNFT.deploy();

        return { gachaMintExtension, gachaPaymentExtension, gachaPon, testNft, owner, addr1, addr2, addr3 };
    }

    it("Should mint Test NFT successfully", async function () {
        const { testNft, owner, addr1 } = await loadFixture(deployFixture);
        await testNft.connect(owner).safeMint(addr1.address, testMetadata);
        expect(await testNft.balanceOf(addr1.address)).to.equal(1);
        expect(await testNft.tokenURI(1)).to.equal(testMetadata);
    });

    it("Should gacha creater successfully can mint GachaPon NFT", async function () {
        const { gachaPon, owner, addr1 } = await loadFixture(deployFixture);

        // mint by contract owner
        const mintFee = 30; //usd
        await gachaPon.connect(owner).mint(addr1.address, testMetadata, mintFee);
        expect(await gachaPon.balanceOf(addr1.address)).to.equal(1);
        expect(await gachaPon.tokenURI(1)).to.equal(testMetadata);

        // view all token datas
        const [uris, fees] = await gachaPon.getAllGachaBoxDatas();
        expect(uris[0]).to.equal(testMetadata);
        expect(fees[0]).to.equal(30);
    });

    it("Should gacha creater successfully mint GachaPon NFT", async function () {
        const { gachaPon, owner, addr1 } = await loadFixture(deployFixture);

        // mint by contract owner
        const mintFee = 30; //usd
        await gachaPon.connect(owner).mint(addr1.address, testMetadata, mintFee);
        expect(await gachaPon.balanceOf(addr1.address)).to.equal(1);
        expect(await gachaPon.tokenURI(1)).to.equal(testMetadata);

        // view all token datas
        const [uris, fees] = await gachaPon.getAllGachaBoxDatas();
        expect(uris[0]).to.equal(testMetadata);
        expect(fees[0]).to.equal(30);
    });

    it("Should successfully manage a capsule NFT", async function () {
        const { testNft, gachaPon, owner, addr1, addr2, addr3 } = await loadFixture(deployFixture);

        // mint gacha NFT
        const mintFee = 30; //usd
        await gachaPon.connect(owner).mint(addr1.address, testMetadata, mintFee);

        // mint capsule NFT
        await testNft.connect(owner).safeMint(addr1.address, testMetadata);

        // transfer capsule NFT to gacha NFT
        const parentId = ethers.BigNumber.from(1);
        const _data = ethers.utils.hexZeroPad(parentId.toHexString(), 32); // 0x0000000000000000000000000000000000000000000000000000000000000001
        const abi_1 = ["function safeTransferFrom(address,address,uint256,bytes) public"];
        const testNftContract = new ethers.Contract(testNft.address, abi_1, addr1);
        await testNftContract["safeTransferFrom(address,address,uint256,bytes)"](
            addr1.address,
            gachaPon.address,
            1,
            _data
        );
        const capsuleContracts = await gachaPon.getAllCapsuleContractsById(1);
        expect(capsuleContracts.length).to.equal(1);
        expect(capsuleContracts[0]).to.equal(testNft.address);

        // check owner
        const rootOwner = ethers.utils.getAddress(ethers.utils.hexDataSlice(await gachaPon.rootOwnerOf(1), 12));
        expect(rootOwner).to.equal(addr1.address);

        // approve external contract/address to transfer capsuleNFT
        const gachaBoxId = 1;
        const capsuleNftId = 1;
        await gachaPon.connect(addr1).approve(addr2.address, gachaBoxId);

        // safeTransferChild a capsule NFT to addr3 by addr2
        const abi_2 = ["function safeTransferChild(uint256,address,address,uint256) external"];
        const gachaContract = new ethers.Contract(gachaPon.address, abi_2, addr2);
        await gachaContract["safeTransferChild(uint256,address,address,uint256)"](
            gachaBoxId,
            addr3.address,
            capsuleContracts[0],
            capsuleNftId
        );
        expect(await testNft.ownerOf(capsuleNftId)).to.equal(addr3.address);
    });

    it("Should successfully register and open gacha", async function () {
        const { gachaPon, owner, addr1, addr2, addr3 } = await loadFixture(deployFixture);

        // set gacha mint extension
        await gachaPon.connect(owner).updateSlashMintExtension(addr2.address); // addr2 is mint extension

        // mint gacha NFT by mint extension
        await gachaPon.connect(addr2).mintForSlashPayment(addr1.address);
        const rootOwner = ethers.utils.getAddress(ethers.utils.hexDataSlice(await gachaPon.rootOwnerOf(1), 12));
        expect(rootOwner).to.equal(addr1.address);

        // update gacha info by gacha owner
        await gachaPon.connect(addr1).updateGachaInfo(1, testMetadata, 30); // gachaId, metadata, gachaFee(usd)
        expect(await gachaPon.getGachaFeeById(1)).to.equal(30);
        expect(await gachaPon.tokenURI(1)).to.equal(testMetadata);

        // get gacah metadata
        const [uris, fees] = await gachaPon.getAllGachaBoxDatas();
        expect(uris[0]).to.equal(testMetadata);
        expect(fees[0]).to.equal(30);
    });
});
