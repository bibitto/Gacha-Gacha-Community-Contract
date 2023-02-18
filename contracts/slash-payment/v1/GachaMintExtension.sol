// SPDX-License-Identifier: MIT
pragma solidity >=0.8.18;

import '../../GachaPon.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import '../../interfaces/ISlashCustomPlugin.sol';
import '../../libs/UniversalERC20.sol';

contract GachaMintExtensionV1 is ISlashCustomPlugin, Ownable {
    using UniversalERC20 for IERC20;

    GachaPon private _GachaPon;
    uint256 private _fee;

    mapping(string => uint256) public purchaseInfo;

    constructor(address gachaPon_, uint256 fee_) {
        _GachaPon = GachaPon(gachaPon_);
        _fee = fee_;
    }

    function updateGachaPon(address newGachaPon) public onlyOwner {
        _GachaPon = GachaPon(newGachaPon);
    }

    function updateMintFee(uint256 newFee) public onlyOwner {
        _fee = newFee;
    }

    function getMintFee() public view returns(uint256 fee) {
      return _fee;
    }

    function receivePayment(
        address receiveToken,
        uint256 amount,
        string calldata paymentId,
        string calldata optional,
        bytes calldata /** reserved */
    ) external payable override {
        require(amount >= _fee * 10**6 , "insufficient amount");
        IERC20(receiveToken).universalTransferFrom(msg.sender, owner(), amount);
        afterReceived(paymentId, optional);
    }

    function afterReceived(string memory paymentId, string memory) internal {
        uint256 tokenId = _GachaPon.mintForSlashPayment(tx.origin);
        purchaseInfo[paymentId] = tokenId;
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
     * - Return true
     */
    function supportSlashExtensionInterface()
        external
        pure
        override
        returns (uint8)
    {
        return 1;
    }
}