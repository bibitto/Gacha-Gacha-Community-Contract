// SPDX-License-Identifier: MIT
pragma solidity >=0.8.18;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol';
import "./interfaces/IERC998ERC721TopDown.sol";
import "./interfaces/IERC998ERC721TopDownEnumerable.sol";
import "./interfaces/IERC998ERC721BottomUp.sol";
import "./GachaPaymentExtension.sol";

import "hardhat/console.sol";

contract GachaPon is ERC721URIStorage, Ownable, IERC998ERC721TopDown, IERC998ERC721TopDownEnumerable  {

    bytes4 constant ERC998_MAGIC_VALUE = 0xcd740db5;
    //from zepellin ERC721Receiver.sol
    bytes4 constant ERC721_RECEIVED_OLD = 0xf0b9e5ba; //old version
    bytes4 constant ERC721_RECEIVED_NEW = 0x150b7a02; //new version

    uint256 public tokenCount;
    address private _slashMintExtension;

    mapping(uint256 gachaBoxId => uint256 fee) private gachaFees;
    mapping(uint256 gachaBoxId => address extension) private tokenIdToPaymentExtension;
    // ERC998
    mapping(uint256 gachaPonId => address gachaPonOwner) internal tokenIdToTokenOwner;
    mapping(address rootOwner => mapping(uint256 gachaBoxId  => address approved)) internal rootOwnerAndTokenIdToApprovedAddress;
    mapping(address gachaPonOwner => uint256 gachaPonCount) internal tokenOwnerToTokenCount;
    mapping(address gachaPonOwner => mapping(address operator => bool isApproved)) internal tokenOwnerToOperators;
    mapping(uint256 gachaBoxId => address[] capsuleContracts) private childContracts;
    mapping(uint256 gachaBoxId => mapping(address capsuleContract => uint256 index)) private childContractIndex;
    mapping(uint256 gachaBoxId => mapping(address capsuleContract => uint256[] capsuleIds)) private childTokens;
    mapping(uint256 gachaBoxId => mapping(address capsuleContract => mapping(uint256 capsuleId => uint256 index))) private childTokenIndex;
    mapping(address capsuleContract => mapping(uint256 capsuleId => uint256 gachaBoxId)) internal childTokenOwner;

    constructor() ERC721("Non-Fungible Gacha-Pon", "GACHA") {}

    modifier onlySlashPayment {
        require(msg.sender == _slashMintExtension, 'not slash payment contract');
        _;
    }

    function getGachaFeeById(uint256 _tokenId) external view returns (uint256 fee) {
        require(_tokenId > 0 && _tokenId <= tokenCount, 'invalid tokenId');
        return gachaFees[_tokenId];
    }

    function updateGachaInfo(uint256 _tokenId, string memory _tokenURI, uint256 _newFee) external {
        require(_tokenId > 0 && _tokenId <= tokenCount, 'invalid tokenId');
        require(tokenIdToTokenOwner[_tokenId] == msg.sender && address(uint160(bytes20(uint160(uint256(rootOwnerOf(_tokenId)))))) == msg.sender, 'allowed only owner');
        gachaFees[_tokenId] = _newFee;
        super._setTokenURI(_tokenId, _tokenURI);
    }

    function registerPaymentExtension(uint256 _tokenId, address operator) external {
        require(_tokenId > 0 && _tokenId <= tokenCount, 'invalid tokenId');
        require(tokenIdToTokenOwner[_tokenId] == msg.sender && address(uint160(bytes20(uint160(uint256(rootOwnerOf(_tokenId)))))) == msg.sender, 'allowed only owner');
        tokenIdToPaymentExtension[_tokenId] = operator;
    }

    function openGachaPon(address extension, uint256 _tokenId) external {
        require(_tokenId > 0 && _tokenId <= tokenCount, 'invalid tokenId');
        require(extension != address(0), 'given address is null');
        require(tokenIdToTokenOwner[_tokenId] == msg.sender && address(uint160(bytes20(uint160(uint256(rootOwnerOf(_tokenId)))))) == msg.sender, 'not allowed');
        require(tokenIdToPaymentExtension[_tokenId] == extension, 'have not registered payment extension');
        require(GachaPaymentExtension(extension).checkRegisteredGachaPonId() == 0, 'already opened');
        GachaPaymentExtension(extension).updateRegisteredGachaPonId(_tokenId);
        approve(extension, _tokenId);
    }

    function closeGachaPon(address extension, uint256 _tokenId) external {
        require(_tokenId > 0 && _tokenId <= tokenCount, 'invalid tokenId');
        require(extension != address(0), 'given address is null');
        require(tokenIdToTokenOwner[_tokenId] == msg.sender && address(uint160(bytes20(uint160(uint256(rootOwnerOf(_tokenId)))))) == msg.sender, 'not allowed');
        require(tokenIdToPaymentExtension[_tokenId] == extension, 'have not registered payment extension');
        require(GachaPaymentExtension(extension).checkRegisteredGachaPonId() != 0, 'already closed');
        GachaPaymentExtension(extension).updateRegisteredGachaPonId(0);
        approve(address(0), _tokenId);
    }

    function updateSlashMintExtension(address newContract) external onlyOwner {
        _slashMintExtension = newContract;
    }

    function mintForSlashPayment(address recipient) external onlySlashPayment returns (uint256) {
        require(recipient != address(0), 'invalid address');
        tokenCount++;
        uint256 tokenCount_ = tokenCount;
        tokenIdToTokenOwner[tokenCount_] = recipient;
        tokenOwnerToTokenCount[recipient]++;
        super._mint(recipient, tokenCount_);
        return tokenCount_;
    }

    function mint(address recipient, string memory _tokenURI, uint256 _newFee) external onlyOwner returns (uint256) {
        require(recipient != address(0), 'invalid address');
        tokenCount++;
        uint256 tokenCount_ = tokenCount;
        tokenIdToTokenOwner[tokenCount_] = recipient;
        tokenOwnerToTokenCount[recipient]++;
        gachaFees[tokenCount_] = _newFee;
        super._mint(recipient, tokenCount_);
        super._setTokenURI(tokenCount_, _tokenURI);
        return tokenCount_;
    }

    /**
     * ERC721 - ERC721URIStorage
     */

    function burn(uint256 _tokenId) public onlyOwner {
        super._burn(_tokenId);
    }

    function tokenURI(uint256 _tokenId) public view override returns (string memory) {
        return super.tokenURI(_tokenId);
    }

    function ownerOf(uint256 _tokenId) public view override returns (address tokenOwner) {
        tokenOwner = tokenIdToTokenOwner[_tokenId];
        require(tokenOwner != address(0), 'given address is invalid');
        return tokenOwner;
    }

    function balanceOf(address _tokenOwner) public view override returns (uint256) {
        require(_tokenOwner != address(0), 'given address is invalid');
        return tokenOwnerToTokenCount[_tokenOwner];
    }

    function approve(address _approved, uint256 _tokenId) public override {
        address rootOwner = address(uint160(bytes20(uint160(uint256(rootOwnerOf(_tokenId))))));
        require(rootOwner == msg.sender || tokenOwnerToOperators[rootOwner][msg.sender], 'do not have the rigth to approve');
        rootOwnerAndTokenIdToApprovedAddress[rootOwner][_tokenId] = _approved;
        emit Approval(rootOwner, _approved, _tokenId);
    }

    function getApproved(uint256 _tokenId) public view override returns (address)  {
        address rootOwner = address(uint160(bytes20(uint160(uint256(rootOwnerOf(_tokenId))))));
        return rootOwnerAndTokenIdToApprovedAddress[rootOwner][_tokenId];
    }

    function setApprovalForAll(address _operator, bool _approved) public override {
        require(_operator != address(0), 'operator address is null');
        tokenOwnerToOperators[msg.sender][_operator] = _approved;
        emit ApprovalForAll(msg.sender, _operator, _approved);
    }

    function isApprovedForAll(address _owner, address _operator) public view override returns (bool)  {
        require(_owner != address(0), 'owner address is null');
        require(_operator != address(0), 'operator address is null');
        return tokenOwnerToOperators[_owner][_operator];
    }

    /**
     * ERC998ERC721 - TopDown
     */

    function rootOwnerOf(uint256 _tokenId) public view returns (bytes32 rootOwner) {
        return rootOwnerOfChild(address(0), _tokenId);
    }

    function _ownerOfChild(address _childContract, uint256 _childTokenId) internal view returns (address parentTokenOwner, uint256 parentTokenId) {
        parentTokenId = childTokenOwner[_childContract][_childTokenId];
        require(parentTokenId > 0 || childTokenIndex[parentTokenId][_childContract][_childTokenId] > 0, 'the given token does not exist');
        return (tokenIdToTokenOwner[parentTokenId], parentTokenId);
    }

    // returns the owner at the top of the tree of composables
    // Use Cases handled:
    // Case 1: Token owner is this contract and token.
    // Case 2: Token owner is other top-down composable
    // Case 3: Token owner is other contract
    // Case 4: Token owner is user
    function rootOwnerOfChild(address _childContract, uint256 _childTokenId) public view returns (bytes32 rootOwner) {
        address rootOwnerAddress;
        if (_childContract != address(0)) {
            (rootOwnerAddress, _childTokenId) = _ownerOfChild(_childContract, _childTokenId);
        }
        else {
            rootOwnerAddress = tokenIdToTokenOwner[_childTokenId];
        }
        // Case 1: Token owner is this contract and token.
        while (rootOwnerAddress == address(this)) {
            (rootOwnerAddress, _childTokenId) = _ownerOfChild(rootOwnerAddress, _childTokenId);
        }

        bool callSuccess;
        // 0xed81cdda == rootOwnerOfChild(address,uint256)
        bytes memory callData = abi.encodeWithSelector(0xed81cdda, address(this), _childTokenId);
        assembly {
            callSuccess := staticcall(gas(), rootOwnerAddress, add(callData, 0x20), mload(callData), callData, 0x20)
            if callSuccess {
                rootOwner := mload(callData)
            }
        }
        if(callSuccess == true && rootOwner >> 224 == ERC998_MAGIC_VALUE) {
            // Case 2: Token owner is other top-down composable
            return rootOwner;
        }
        else {
            // Case 3: Token owner is other contract
            // Or
            // Case 4: Token owner is user
            return ERC998_MAGIC_VALUE << 224 | bytes32(uint256(uint160(rootOwnerAddress)));
        }
    }

    function ownerOfChild(address _childContract, uint256 _childTokenId) external view returns (bytes32 parentTokenOwner, uint256 parentTokenId) {
        parentTokenId = childTokenOwner[_childContract][_childTokenId];
        require(parentTokenId > 0 || childTokenIndex[parentTokenId][_childContract][_childTokenId] > 0, 'the given token does not exist');
        return (ERC998_MAGIC_VALUE << 224 | bytes32(uint256(uint160(tokenIdToTokenOwner[parentTokenId]))), parentTokenId);
    }

    function removeChild(uint256 _tokenId, address _childContract, uint256 _childTokenId) private {
        uint256 tokenIndex = childTokenIndex[_tokenId][_childContract][_childTokenId];
        require(tokenIndex != 0, "Child token not owned by token.");

        // remove child token
        uint256 lastTokenIndex = childTokens[_tokenId][_childContract].length - 1;
        uint256 lastToken = childTokens[_tokenId][_childContract][lastTokenIndex];
        if (_childTokenId == lastToken) {
            childTokens[_tokenId][_childContract][tokenIndex - 1] = lastToken;
            childTokenIndex[_tokenId][_childContract][lastToken] = tokenIndex;
        }
        delete childTokens[_tokenId][_childContract][childTokens[_tokenId][_childContract].length-1];
        delete childTokenIndex[_tokenId][_childContract][_childTokenId];
        delete childTokenOwner[_childContract][_childTokenId];

        // remove contract
        if (lastTokenIndex == 0) {
            uint256 lastContractIndex = childContracts[_tokenId].length - 1;
            address lastContract = childContracts[_tokenId][lastContractIndex];
            if (_childContract != lastContract) {
                uint256 contractIndex = childContractIndex[_tokenId][_childContract];
                childContracts[_tokenId][contractIndex] = lastContract;
                childContractIndex[_tokenId][lastContract] = contractIndex;
            }
            delete childContracts[_tokenId][childContracts[_tokenId].length-1];
            delete childContractIndex[_tokenId][_childContract];
        }
    }

    function safeTransferChild(uint256 _fromTokenId, address _to, address _childContract, uint256 _childTokenId) external {
        uint256 tokenId = childTokenOwner[_childContract][_childTokenId];
        require(tokenId > 0 || childTokenIndex[tokenId][_childContract][_childTokenId] > 0, 'given datas are invalid');
        require(tokenId == _fromTokenId, 'given tokenId of gacha box is invalid');
        require(_to != address(0), 'cannot transfer to null address');
        address rootOwner = address(uint160(bytes20(uint160(uint256(rootOwnerOf(tokenId))))));
        require(rootOwner == msg.sender || tokenOwnerToOperators[rootOwner][msg.sender] ||
        rootOwnerAndTokenIdToApprovedAddress[rootOwner][tokenId] == msg.sender, 'do not have the right to transfer ');
        removeChild(tokenId, _childContract, _childTokenId);
        IERC721(_childContract).safeTransferFrom(address(this), _to, _childTokenId);
        emit TransferChild(tokenId, _to, _childContract, _childTokenId);
    }

    function safeTransferChild(uint256 _fromTokenId, address _to, address _childContract, uint256 _childTokenId, bytes calldata _data) external {
        uint256 tokenId = childTokenOwner[_childContract][_childTokenId];
        require(tokenId > 0 || childTokenIndex[tokenId][_childContract][_childTokenId] > 0, 'the given token does not exist');
        require(tokenId == _fromTokenId, 'owner does not match to from id ');
        require(_to != address(0), 'cannot transfer to null address');
        address rootOwner = address(uint160(bytes20(uint160(uint256(rootOwnerOf(tokenId))))));
        require(rootOwner == msg.sender || tokenOwnerToOperators[rootOwner][msg.sender] ||
        rootOwnerAndTokenIdToApprovedAddress[rootOwner][tokenId] == msg.sender, 'do not have the right to transfer ');
        removeChild(tokenId, _childContract, _childTokenId);
        IERC721(_childContract).safeTransferFrom(address(this), _to, _childTokenId, _data);
        emit TransferChild(tokenId, _to, _childContract, _childTokenId);
    }

    function transferChild(uint256 _fromTokenId, address _to, address _childContract, uint256 _childTokenId) external {
        uint256 tokenId = childTokenOwner[_childContract][_childTokenId];
        require(tokenId > 0 || childTokenIndex[tokenId][_childContract][_childTokenId] > 0, 'the given token does not exist');
        require(tokenId == _fromTokenId, 'owner does not match to from id');
        require(_to != address(0), 'cannot transfer to null address');
        address rootOwner = address(uint160(bytes20(uint160(uint256(rootOwnerOf(tokenId))))));
        require(rootOwner == msg.sender || tokenOwnerToOperators[rootOwner][msg.sender] ||
        rootOwnerAndTokenIdToApprovedAddress[rootOwner][tokenId] == msg.sender, 'do not have the right to transfer');
        removeChild(tokenId, _childContract, _childTokenId);
        //this is here to be compatible with cryptokitties and other old contracts that require being owner and approved
        // before transferring.
        //does not work with current standard which does not allow approving self, so we must let it fail in that case.
        //0x095ea7b3 == "approve(address,uint256)"
        bytes memory callData = abi.encodeWithSelector(0x095ea7b3, this, _childTokenId);
        assembly {
            let success := call(gas(), _childContract, 0, add(callData, 0x20), mload(callData), callData, 0)
        }
        IERC721(_childContract).transferFrom(address(this), _to, _childTokenId);
        emit TransferChild(tokenId, _to, _childContract, _childTokenId);
    }

    function transferChildToParent(uint256 _fromTokenId, address _toContract, uint256 _toTokenId, address _childContract, uint256 _childTokenId, bytes calldata _data) external {
        uint256 tokenId = childTokenOwner[_childContract][_childTokenId];
        require(tokenId > 0 || childTokenIndex[tokenId][_childContract][_childTokenId] > 0, 'the given token does not exist');
        require(tokenId == _fromTokenId, 'owner does not match to from id');
        require(_toContract != address(0), 'cannot transfer to null address');
        address rootOwner = address(uint160(bytes20(uint160(uint256(rootOwnerOf(tokenId))))));
        require(rootOwner == msg.sender || tokenOwnerToOperators[rootOwner][msg.sender] ||
        rootOwnerAndTokenIdToApprovedAddress[rootOwner][tokenId] == msg.sender, 'do not have the right to transfer');
        removeChild(_fromTokenId, _childContract, _childTokenId);
        IERC998ERC721BottomUp(_childContract).transferToParent(address(this), _toContract, _toTokenId, _childTokenId, _data);
        emit TransferChild(_fromTokenId, _toContract, _childContract, _childTokenId);
    }

    // this contract has to be approved first in _childContract
    function getChild(address _from, uint256 _tokenId, address _childContract, uint256 _childTokenId) external {
        receiveChild(_from, _tokenId, _childContract, _childTokenId);
        require(_from == msg.sender ||
        IERC721(_childContract).isApprovedForAll(_from, msg.sender) ||
        IERC721(_childContract).getApproved(_childTokenId) == msg.sender, 'cannot get child token');
        IERC721(_childContract).transferFrom(_from, address(this), _childTokenId);
    }

    function onERC721Received(address _from, uint256 _childTokenId, bytes calldata _data) external returns (bytes4) {
        require(_data.length > 0, "_data must contain the uint256 tokenId to transfer the child token to.");
        // convert up to 32 bytes of_data to uint256, owner nft tokenId passed as uint in bytes
        uint256 tokenId;
        assembly {tokenId := calldataload(132)}
        if (_data.length < 32) {
            tokenId = tokenId >> 256 - _data.length * 8;
        }
        receiveChild(_from, tokenId, msg.sender, _childTokenId);
        require(IERC721(msg.sender).ownerOf(_childTokenId) != address(0), "Child token not owned.");
        return ERC721_RECEIVED_OLD;
    }


    function onERC721Received(address _operator, address _from, uint256 _childTokenId, bytes calldata _data) external returns (bytes4) {
        require(_data.length > 0, "_data must contain the uint256 tokenId to transfer the child token to.");
        // convert up to 32 bytes of_data to uint256, owner nft tokenId passed as uint in bytes
        uint256 tokenId;
        assembly {tokenId := calldataload(164)}
        if (_data.length < 32) {
            tokenId = tokenId >> 256 - _data.length * 8;
        }
        receiveChild(_from, tokenId, msg.sender, _childTokenId);
        require(IERC721(msg.sender).ownerOf(_childTokenId) != address(0), "Child token not owned.");
        return ERC721_RECEIVED_NEW;
    }


    function receiveChild(address _from, uint256 _tokenId, address _childContract, uint256 _childTokenId) private {
        require(tokenIdToTokenOwner[_tokenId] != address(0), "_tokenId does not exist.");
        require(childTokenIndex[_tokenId][_childContract][_childTokenId] == 0, "Cannot receive child token because it has already been received.");
        uint256 childTokensLength = childTokens[_tokenId][_childContract].length;
        if (childTokensLength == 0) {
            childContractIndex[_tokenId][_childContract] = childContracts[_tokenId].length;
            childContracts[_tokenId].push(_childContract);
        }
        childTokens[_tokenId][_childContract].push(_childTokenId);
        childTokenIndex[_tokenId][_childContract][_childTokenId] = childTokensLength + 1;
        childTokenOwner[_childContract][_childTokenId] = _tokenId;
        emit ReceivedChild(_from, _tokenId, _childContract, _childTokenId);
    }

    function childExists(address _childContract, uint256 _childTokenId) external view returns (bool) {
        uint256 tokenId = childTokenOwner[_childContract][_childTokenId];
        return childTokenIndex[tokenId][_childContract][_childTokenId] != 0;
    }

    function totalChildContracts(uint256 _tokenId) external view returns (uint256) {
        return childContracts[_tokenId].length;
    }

    function childContractByIndex(uint256 _tokenId, uint256 _index) external view returns (address childContract) {
        require(_index < childContracts[_tokenId].length, "Contract address does not exist for this token and index.");
        return childContracts[_tokenId][_index];
    }

    function totalChildTokens(uint256 _tokenId, address _childContract) external view returns (uint256) {
        return childTokens[_tokenId][_childContract].length;
    }

    function childTokenByIndex(uint256 _tokenId, address _childContract, uint256 _index) external view returns (uint256 childTokenId) {
        require(_index < childTokens[_tokenId][_childContract].length, "Token does not own a child token at contract address and index.");
        return childTokens[_tokenId][_childContract][_index];
    }

    function getAllCapsuleContractsById(uint256 _tokenId) public view returns (address[] memory capsuleContracts) {
        return childContracts[_tokenId];
    }

    function getAllCapsuleTokens(uint256 _tokenId, address _capsuleContract) public view returns (uint256[] memory tokenIds) {
        return childTokens[_tokenId][_capsuleContract];
    }

    function getAllCapsuleTokenURIs(address _contract, uint256[] memory tokenIds) public view returns (string[] memory uris) {
        string[] memory uris_ = new string[](tokenIds.length);
        for (uint256 i; i < tokenIds.length; i++) {
            uris[i] = ERC721URIStorage(_contract).tokenURI(tokenIds[i]);
        }
        return uris_;
    }

    function getAllGachaBoxDatas() public view returns (string[] memory uris, uint256[] memory fees) {
        string[] memory uris_ = new string[](tokenCount);
        uint256[] memory fees_ = new uint256[](tokenCount);
        for (uint256 i; i < tokenCount; i++) {
            uris_[i] = tokenURI(i + 1);
            fees_[i] = gachaFees[i + 1];
        }
        return (uris_, fees_);
    }

    function getOpendGachaBoxURIs() public view returns (string[] memory uris, uint256[] memory fees) {
        string[] memory uris_ = new string[](tokenCount);
        uint256[] memory fees_ = new uint256[](tokenCount);
        for (uint256 i; i < tokenCount; i++) {
            if (getApproved(i + 1) != address(0)) {
                uris_[i] = tokenURI(i + 1);
                fees_[i] = gachaFees[i + 1];
            }
        }
        return (uris_, fees_);
    }
}