// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import './IAzWorldBox.sol';
import "./IUniswapV2Pair.sol";
import "./IUniswapV2Router02.sol";
import "./IERC20.sol";
import "hardhat/console.sol";

contract NFTSale is ReentrancyGuard, Ownable {
    address public boxContract;
    address payable public recipientAddress;
    address payable public devAddress;
    address public burnAddress = address(0);
    uint8 burnPercent = 30;
    IUniswapV2Pair public immutable azwPair;
    IUniswapV2Router02 public immutable router;
    IERC20 public immutable azw;
    mapping(uint8 => PurchaseRound) private _purchaseRounds;
    mapping(uint8 => bool) private _purchaseRoundExist;
    mapping(uint8 => mapping(address => bool)) public roundWhiteList;
    mapping(uint8 => mapping(address => uint8)) public roundMinted;
    mapping(uint8 => uint256) public roundWhiteListCount;
    mapping(uint8 => uint16) public roundLimitNftPerAddress;
    string public currentRoundName;
    uint8 public currentRoundId;

    struct PurchaseRound {
        uint16 supply;
        uint256 startTime;
        uint256 endTime;
        uint256 priceInBnb;
        uint8 whitelistDiscountPercent;
        uint16 minted;
    }
    event OpenPurchaseRound(
        uint8 id,
        uint16 supply,
        uint256 startTime,
        uint256 endTime,
        uint256 price,
        uint8 whitelistDiscountPercent
    );
    event PurchasedNft(uint8 roundId, uint256 price);
    modifier preventContractCalls{
        require(msg.sender == tx.origin,"Cannot be called from other smart contracts");
        _;
    }
    
    function setWhitelist(uint8 _roundId, address[] memory _whitelists) external onlyOwner{
        uint8 j=0;
        for (j = 0; j < _whitelists.length; j++) {
            roundWhiteList[_roundId][_whitelists[j]] = true;
        }
        roundWhiteListCount[_roundId] = _whitelists.length;
    }

    function setWhitelistPercent(uint8 _roundId,  uint8 _newPercent) external onlyOwner{
        _purchaseRounds[_roundId].whitelistDiscountPercent = _newPercent;
    }

    function getAmountOfAzwToPay(uint256 _amountOfBox, uint8 roundId) public view returns(uint256){
        (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast) = azwPair.getReserves();
        return _amountOfBox * (_purchaseRounds[roundId].priceInBnb / (reserve1 / reserve0));
    }

    function withdrawAllTo(address payable _to) external onlyOwner{
        _to.transfer(address(this).balance);
    }
    
    constructor(
        address _boxContract,
        address payable _recipientAddress,
        address payable _devAddress
    ) {
        require(
            _recipientAddress != address(0) && _devAddress != address(0),
            "Cannot be address 0"
        );
        azwPair = IUniswapV2Pair(0xB867aeE7E2288Daa3e58bCAb10ec42eB21DC80b4);
        azw = IERC20(0x1F2Cfde19976A2bF0A250900f7aCe9c362908C93);
        router = IUniswapV2Router02(0x10ED43C718714eb63d5aA57B78B54704E256024E);
        recipientAddress = _recipientAddress;
        devAddress = _devAddress;
        boxContract = _boxContract;
    }
    
    /**
     * @dev Open an event with box type, time duration and price, supply, ...
     * @param _id uint8: id of the event
     * @param _startTime uint256: start time of the event
     * @param _endTime uint256: end time of the event
     * @param _priceInBnb uint256: price of the NFT in BNB
     * @param _supply uint256: supply of the NFT
     * @param _limitPerAddress uint16: limit quantity of the NFT an address can buy
     * Emit OpenPurchaseRound event
     */
    function openPurchaseRound(
        uint8 _id,
        uint16 _supply,
        uint256 _startTime,
        uint256 _endTime,
        uint256 _priceInBnb,
        uint8 _whitelistDiscountPercent,
        uint16 _limitPerAddress,
        string memory roundName
    ) public onlyOwner roundNotExist(_id) {
        require(_endTime > _startTime, "End time must be after start time");
        require(_priceInBnb > 0, "Price must be greater than 0");
        require(_supply > 0, "Supply must be greater than 0");
        currentRoundId = _id;
        currentRoundName = roundName;
        _purchaseRounds[_id] = PurchaseRound(
            _supply,
            _startTime,
            _endTime,
            _priceInBnb,
            _whitelistDiscountPercent,
            0
        );

        _purchaseRoundExist[_id] = true;
        roundLimitNftPerAddress[_id] = _limitPerAddress;

        emit OpenPurchaseRound(
            _id,
            _supply,
            _startTime,
            _endTime,
            _priceInBnb,
            _whitelistDiscountPercent
        );
    }
    modifier roundNotExist(uint8 _roundId) {
        require(
            _purchaseRoundExist[_roundId] == false,
            "Purchase round already exists"
        );
        _;
    }

    modifier roundAvailable(uint8 _roundId) {
        require(
            _purchaseRoundExist[_roundId] == true,
            "Purchase round does not exist"
        );
        PurchaseRound memory purchaseRound = _purchaseRounds[_roundId];
        require(
            purchaseRound.startTime <= block.timestamp &&
                purchaseRound.endTime >= block.timestamp,
            "Purchase round is not active"
        );
        require(
            purchaseRound.minted < purchaseRound.supply,
            "Purchase round is sold out"
        );
        _;
    }

    function setRoundStartTime(uint8 _roundId, uint256 _startTime)
        public
        onlyOwner
    {
        require(
            _purchaseRoundExist[_roundId] == true,
            "Purchase round does not exist"
        );
        require(_startTime >= block.timestamp, "Start time must be after now");
        PurchaseRound storage purchaseRound = _purchaseRounds[_roundId];
        require(
            purchaseRound.startTime > block.timestamp,
            "Cannot update starTime of a round after it has started"
        );
        purchaseRound.startTime = _startTime;
    }

    function setRoundEndtime(uint8 _roundId, uint256 _endTime)
        public
        onlyOwner
    {
        require(
            _purchaseRoundExist[_roundId] == true,
            "Purchase round does not exist"
        );
        require(_endTime >= block.timestamp, "End time must be after now");
        PurchaseRound storage purchaseRound = _purchaseRounds[_roundId];
        require(
            purchaseRound.endTime > block.timestamp,
            "Cannot update endTime of a round after it has ended"
        );
        purchaseRound.endTime = _endTime;
    }

    /**
     * @dev getRoundInfo
     * @param _roundId uint8: id of the event
     */
    function getRoundInfo(uint8 _roundId)
        public
        view
        returns (PurchaseRound memory purchaseRound)
    {
        require(
            _purchaseRoundExist[_roundId] == true,
            "Purchase round does not exist"
        );
        purchaseRound = _purchaseRounds[_roundId];
    }

    function setRoundPriceInBnb(uint8 _roundId, uint256 _price)
        public
        onlyOwner
    {
        require(_price > 0, "Price must be greater than 0");

        PurchaseRound storage purchaseRound = _purchaseRounds[_roundId];

        require(
            purchaseRound.minted == 0,
            "Cannot change price of a round after someone minted an NFT"
        );
        purchaseRound.priceInBnb = _price;
    }
    
    /**
     * @dev Buy event NFT
     * @param _roundId uint8: id of the event
     * Emit PurchasedBox event
     */
    function buyNFT(uint8 _roundId, uint8 _mintAmount, bool useAzw)
        public payable
        nonReentrant
        roundAvailable(_roundId) preventContractCalls
    {
        require(
            _purchaseRoundExist[_roundId] == true,
            "Purchase round does not exist"
        );
        address buyer = msg.sender;
        require(buyer != address(0), "Sender cannot be the null address");
        PurchaseRound storage purchaseRound = _purchaseRounds[_roundId];
        require(_mintAmount > 0,"Mint amount must be greater than zero");
        require(buyer != address(0), "Buyer cannot be the null address");
        if (roundLimitNftPerAddress[_roundId] > 0) {
            require(
                roundMinted[_roundId][buyer] + _mintAmount <=
                    roundLimitNftPerAddress[_roundId],
                "Mint limit reached"
            );
        }
        require(
            purchaseRound.supply >= purchaseRound.minted + _mintAmount,
            "Not enough NFT in supply"
        );
        if(useAzw){
            uint256 amountOfAzwToPay = getAmountOfAzwToPay(_mintAmount, _roundId);
            if(roundWhiteList[_roundId][msg.sender]){
                amountOfAzwToPay = getAmountOfAzwToPay(_mintAmount, _roundId) * (100 - purchaseRound.whitelistDiscountPercent) / 100;
            }
            //Burn 30% of AZW received

            azw.transferFrom(msg.sender, burnAddress, amountOfAzwToPay * burnPercent / 100);

            // 70% of AZW received goes to devAddress

            azw.transferFrom(msg.sender, devAddress, amountOfAzwToPay - ((amountOfAzwToPay * burnPercent) / 100));
        }
        else{
            uint256 price = purchaseRound.priceInBnb;
            if(roundWhiteList[_roundId][msg.sender]){
                price = purchaseRound.priceInBnb * (100 - purchaseRound.whitelistDiscountPercent) / 100;
            }
            require(msg.value >= price * _mintAmount, "Not enough BNB");
            //70% goes to devAddress
            devAddress.transfer(msg.value - ((msg.value * burnPercent) / 100));
            // 30% buyback and burn
            swapBnbToToken((msg.value * burnPercent) / 100);
            azw.transfer(burnAddress, azw.balanceOf(address(this)));
        }
        purchaseRound.minted += _mintAmount;
        IAzWorldBox(boxContract).mint(msg.sender,1,_mintAmount);
        roundMinted[_roundId][msg.sender] += 1;
        emit PurchasedNft(_roundId, 1);
    }
    function swapBnbToToken(uint256 bnbAmount) private {
        // generate the uniswap pair path of token -> weth
        address[] memory path = new address[](2);
        path[0] = router.WETH();
        path[1] = address(azw);

        // make the swap
        router.swapExactETHForTokensSupportingFeeOnTransferTokens{value:bnbAmount}(
            0, // accept any amount of ETH
            path,
            address(this), // The contract
            block.timestamp
        );
    }
    function changeRecipientAddress(address payable _recipientAddress) external onlyOwner{
        require(_recipientAddress != address(0),"Cannot be zero address");
        recipientAddress = _recipientAddress;
    }
    function changeDevAddress(address payable _newDevAddress) external onlyOwner{
        require(_newDevAddress != address(0),"Cannot be zero address");
        devAddress = _newDevAddress;
    }
    function withdrawAll(address payable _to) external onlyOwner{
        require(_to != address(0) && devAddress != address(0),"Cannot be zero address");
        _to.transfer(address(this).balance);
    }
}
