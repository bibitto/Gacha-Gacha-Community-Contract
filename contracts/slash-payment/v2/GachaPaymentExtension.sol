// SPDX-License-Identifier: MIT
pragma solidity >=0.8.18;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "../../GachaPon.sol";
import "../../interfaces/ISlashCustomPlugin.sol";
import "../../libs/UniversalERC20.sol";

contract GachaPaymentExtension is ISlashCustomPlugin, Ownable {
    using UniversalERC20 for IERC20;
    using SafeMath for uint256;

    address private _gachaPon;
    uint256 private registeredGachaPonId;
    address private commissionReceiver;
    uint256 public commissionPercentage;

    mapping(string paymentId => string info) public purchaseInfo;

    constructor(address gachaPon_, address _commissionReceiver, uint256 _commissionPercentage) {
        _gachaPon = gachaPon_;
        commissionReceiver = _commissionReceiver;
        commissionPercentage = _commissionPercentage;
    }

    function updateRegisteredGachaPonId(uint256 tokenId) external {
        require(_gachaPon == msg.sender, 'do not have permission');
        registeredGachaPonId = tokenId;
    }

    function checkRegisteredGachaPonId() external view returns (uint256 tokenId) {
        return registeredGachaPonId;
    }

    function receivePayment(
        address receiveToken,
        uint256 amount,
        string calldata paymentId,
        string calldata optional,
        bytes calldata /** reserved */
    ) external payable override {
        require(registeredGachaPonId > 0, 'gacha is not registered yet');
        require(GachaPon(_gachaPon).totalChildContracts(registeredGachaPonId) > 0, 'there is no capsule');
        uint256 gachaFee = GachaPon(_gachaPon).getGachaFeeById(registeredGachaPonId) * 10**6; // USD
        require(amount >= gachaFee, "insufficient amount");
        uint256 commissionFee = SafeMath.div(SafeMath.mul(amount, commissionPercentage), 100);
        IERC20(receiveToken).universalTransferFrom(msg.sender, commissionReceiver, commissionFee);
        IERC20(receiveToken).universalTransferFrom(msg.sender, owner(), amount - commissionFee);
        afterReceived(paymentId, optional);
    }

    function afterReceived(string memory paymentId, string memory) internal {
        // get random contract
        uint256 randomNum = uint256(keccak256(abi.encodePacked(block.timestamp, block.number, paymentId)));
        address[] memory capsuleContracts = GachaPon(_gachaPon).getAllCapsuleContractsById(registeredGachaPonId);
        address selectedContract = capsuleContracts[randomNum % capsuleContracts.length];
        // get random NFT
        uint256[] memory tokenIds =  GachaPon(_gachaPon).getAllCapsuleTokens(registeredGachaPonId, selectedContract);
        uint256 selectedTokenId = tokenIds[randomNum % tokenIds.length];
        // transfer random NFT
        GachaPon(_gachaPon).safeTransferChild(registeredGachaPonId, tx.origin, selectedContract, selectedTokenId);
        purchaseInfo[paymentId] = string(abi.encodePacked(selectedContract, selectedTokenId));
    }

    function withdrawToken(address tokenContract) external onlyOwner {
        require(
            IERC20(tokenContract).universalBalanceOf(address(this)) > 0,
            "balance is zero"
        );

        IERC20(tokenContract).universalTransfer(
            msg.sender,
            IERC20(tokenContract).universalBalanceOf(address(this))
        );

        emit TokenWithdrawn(
            tokenContract,
            IERC20(tokenContract).universalBalanceOf(address(this))
        );
    }

    event TokenWithdrawn(address tokenContract, uint256 amount);

    /**
     * @dev Check if the contract is Slash Plugin
     *
     * Requirement
     * - Implement this function in the contract
     * - Return truec
     */
    function supportSlashExtensionInterface()
        external
        pure
        override
        returns (uint8)
    {
        return 2;
    }
}