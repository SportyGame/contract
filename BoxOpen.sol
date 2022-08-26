// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4;

import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/utils/Address.sol";

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./IAzWorldBox.sol";
import "./IAzWorldNFT.sol";
import "hardhat/console.sol";
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";

contract BoxOpen is VRFConsumerBaseV2, Context, Ownable, ReentrancyGuard {
    using Address for address;

    IAzWorldBox public boxAddress;
    IAzWorldNFT public nftAddress;

    uint256 public boxOpenCount;
    uint16 public constant COLLECTION_SIZE = 1000;

    uint256 public collectionStartingIndex;
    uint8[] public nftTypes;

    event BoxOpened(
        uint256 nftId
    );

    VRFCoordinatorV2Interface COORDINATOR;
    // Your subscription ID.
    uint64 s_subscriptionId;

    // BSC coordinator. For other networks,
    // see https://docs.chain.link/docs/vrf-contracts/#configurations
    address vrfCoordinator = 0xc587d9053cd1118f25F645F9E08BB98c9712A4EE;

    // The gas lane to use, which specifies the maximum gas price to bump to.
    // For a list of available gas lanes on each network,
    // see https://docs.chain.link/docs/vrf-contracts/#configurations
    bytes32 keyHash = 0x114f3da0a805b6a67d6e9cd2ec746f7028f1b7376365af575cfea3550dd1aa04;
  
    // Depends on the number of requested values that you want sent to the
    // fulfillRandomWords() function. Storing each word costs about 20,000 gas,
    // so 100,000 is a safe default for this example contract. Test and adjust
    // this limit based on the network that you select, the size of the request,
    // and the processing of the callback request in the fulfillRandomWords()
    // function.
    uint32 callbackGasLimit = 200000;

    // The default is 3, but you can set this higher.
    uint16 requestConfirmations = 3;

    // For this example, retrieve 2 random values in one request.
    // Cannot exceed VRFCoordinatorV2.MAX_NUM_WORDS.
    uint32 numWords =  1;

    uint256[] private s_randomWords;
    uint256 public s_requestId;

    constructor(address _boxAddress, address _nftAddress, uint64 subscriptionId) VRFConsumerBaseV2(vrfCoordinator) {
        boxAddress = IAzWorldBox(_boxAddress);
        nftAddress = IAzWorldNFT(_nftAddress);
        COORDINATOR = VRFCoordinatorV2Interface(vrfCoordinator);
        s_subscriptionId = subscriptionId;
    }

    function loadNftTypes(uint8[] memory types)
        external
        onlyOwner
    {
        for (uint256 i; i < types.length; i++) {
            nftTypes.push(types[i]);
        }
    }

    function changeNftAddress(address _newNFTAddress) external onlyOwner{
        nftAddress = IAzWorldNFT(_newNFTAddress);
    }

    function changeBoxAddress(address _newBoxAddress) external onlyOwner{
        boxAddress = IAzWorldBox(_newBoxAddress);
    }

    // Assumes the subscription is funded sufficiently.
    function requestRandomWords() external onlyOwner {
    // Will revert if subscription is not set and funded.
        s_requestId = COORDINATOR.requestRandomWords(
        keyHash,
        s_subscriptionId,
        requestConfirmations,
        callbackGasLimit,
        numWords
        );
    }

    function fulfillRandomWords(
        uint256, /* requestId */
        uint256[] memory randomWords
        ) internal override {
        require(
            collectionStartingIndex == 0,
            "Metadata starting index already set"
        );

        collectionStartingIndex = (randomWords[0] % COLLECTION_SIZE);

        if (collectionStartingIndex == 0) {
            collectionStartingIndex++;
        }
    }
    function computeOriginalSequenceId(uint256 tokenId)
        internal
        view
        returns (uint256)
    {
        return (tokenId + collectionStartingIndex) % COLLECTION_SIZE;
    }

    function getNftTypeById(uint256 tokenId) public view returns (uint8) {
        uint256 originalSeqId = computeOriginalSequenceId(tokenId);
        return nftTypes[originalSeqId];
    }

    function openBox(uint8 boxId) public nonReentrant {
        address origin = _msgSender();
        require(
            boxAddress.balanceOf(origin, boxId) > 0,
            "You don't have any boxes of this type"
        );
        uint8 nftType = getNftTypeById(nftAddress.mintedNFT());
        boxAddress.burn(origin, boxId, 1);
        nftAddress.safeMint(origin, nftType);
        emit BoxOpened(nftAddress.mintedNFT());
    }

    function onERC1155Received(
        address,
        address,
        uint256,
        uint256,
        bytes memory
    ) public virtual returns (bytes4) {
        return this.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(
        address,
        address,
        uint256[] memory,
        uint256[] memory,
        bytes memory
    ) public virtual returns (bytes4) {
        return this.onERC1155BatchReceived.selector;
    }
}