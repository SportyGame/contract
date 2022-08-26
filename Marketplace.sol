// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Receiver.sol";

contract Marketplace is Ownable, ReentrancyGuard, ERC1155Receiver {
    using Counters for Counters.Counter;
    Counters.Counter private _itemIdCounter;
    Counters.Counter private _itemSoldCount;
    uint256 public saleCount;
    address payable public feeWallet;
    uint256 public feeRate;
    uint256 public feeBasePoints = 100;
    uint256 public lastFeeUpdate;
    address public paymentToken = 0x1F2Cfde19976A2bF0A250900f7aCe9c362908C93; // AZW token address

    struct MarketItem {
        uint256 itemId;
        address nftToken;
        uint256 tokenId;
        address payable seller;
        address payable owner;
        bool usingBnb;
        uint256 price;
        bool sold;
        bool isErc1155;
    }

    mapping(uint256 => MarketItem) public idToMarketItem; 

    event FeeUpdated(
        uint256 oldFeeRate,
        uint256 newFeeRate,
        uint256 lastFeeUpdate
    );
    event ItemOnSale(
        uint256 itemId,
        address nftToken,
        uint256 tokenId,
        address seller,
        uint256 price,
        bool isErc1155
    );
    event ItemSold(
        uint256 itemId,
        address nftToken,
        uint256 tokenId,
        address seller,
        address owner,
        uint256 price,
        bool isErc1155
    );

    event ItemDelist(
        uint256 itemId,
        address nftToken,
        uint256 tokenId,
        address seller,
        uint256 price,
        bool isErc1155
    );

    constructor(address payable _feeWallet, uint256 _feeRate) {
        require(
            _feeWallet != address(0),
            "Fee wallet cannot be the zero address"
        );

        feeWallet = _feeWallet;
        setFeeRate(_feeRate);
    }

    function setFeeWallet(address payable _feeWallet) public onlyOwner {
        require(
            _feeWallet != address(0),
            "Fee wallet cannot be the zero address"
        );
        feeWallet = _feeWallet;
    }

    function setFeeRate(uint256 _feeRate) public onlyOwner {
        require(
            _feeRate > 0 && _feeRate < feeBasePoints,
            "Fee rate must be greater than zero"
        );
        lastFeeUpdate = block.timestamp;
        emit FeeUpdated(feeRate, _feeRate, lastFeeUpdate);
        feeRate = _feeRate;
    }

    function setPaymentToken(address _newToken) public onlyOwner{
        require(_newToken != address(0), "Cannot be zero address");
        paymentToken = _newToken;
    }

    function calculateFee(uint256 _amount) internal view returns (uint256) {
        require(
            (_amount / feeBasePoints) * feeBasePoints == _amount,
            "Amount too small"
        );
        return (_amount * feeRate) / feeBasePoints;
    }

    function placeItemOnSale(
        bool _isErc1155,
        address _nftToken,
        uint256 _tokenId,
        bool _usingBnb,
        uint256 _price
    ) public nonReentrant returns (bool) {
        address origin = _msgSender();
        require(
            _nftToken != address(0),
            "_nftToken cannot be the zero address"
        );
        require(_tokenId != 0, "_tokenId cannot be zero");
        require(_price != 0, "_price cannot be zero");

        _itemIdCounter.increment();
        uint256 _currentItemId = _itemIdCounter.current();
        saleCount++;
        // add item to on sale list
        idToMarketItem[_currentItemId] = MarketItem(
            _currentItemId,
            _nftToken,
            _tokenId,
            payable(origin),
            payable(address(0)),
            _usingBnb,
            _price,
            false,
            _isErc1155
        );
        //transfer nft token to contract

        if (_isErc1155) {
            IERC1155(_nftToken).safeTransferFrom(
                origin,
                address(this),
                _tokenId,
                1,
                ""
            );
        } else {
            IERC721(_nftToken).safeTransferFrom(
                origin,
                address(this),
                _tokenId
            );
        }
        emit ItemOnSale(
            _currentItemId,
            _nftToken,
            _tokenId,
            origin,
            _price,
            _isErc1155
        );
        return true;
    }

    function buyItem(uint256 _itemId) public payable nonReentrant {
        address origin = _msgSender();
        require(_itemId != 0, "_itemId cannot be zero");
        MarketItem storage item = idToMarketItem[_itemId];
        require(item.itemId != 0, "Item does not exist");
        require(item.sold == false, "Item is already sold");
        require(item.seller != origin, "You can't buy your own item");

        uint256 txFee = calculateFee(item.price);
        if(item.usingBnb){
            require(msg.value >= item.price,"Insufficient amount of BNB");
            // pay for fee
            feeWallet.transfer(txFee);
            //pay for seller
            item.seller.transfer(msg.value - txFee);
        }
        else{
        // pay for fee
        IERC20(paymentToken).transferFrom(origin, feeWallet, txFee);
        // pay for seller
        IERC20(paymentToken).transferFrom(
            origin,
            item.seller,
            item.price - txFee
        );
        }

        item.sold = true;
        item.owner = payable(origin);
        // transfer token to buyer
        if (item.isErc1155) {
            IERC1155(item.nftToken).safeTransferFrom(
                address(this),
                origin,
                item.tokenId,
                1,
                ""
            );
        } else {
            IERC721(item.nftToken).safeTransferFrom(
                address(this),
                origin,
                item.tokenId
            );
        }
        _itemSoldCount.increment();
        emit ItemSold(
            item.itemId,
            item.nftToken,
            item.tokenId,
            item.seller,
            origin,
            item.price,
            item.isErc1155
        );
    }

    function getItemsOnSale() public view returns (MarketItem[] memory) {
        uint256 totalItemCount = saleCount;
        uint256 itemCount = 0;
        uint256 currentIndex = 0;

        for (uint256 i = 1; i <= totalItemCount; i++) {
            if (idToMarketItem[i].sold == false) {
                itemCount++;
            }
        }

        MarketItem[] memory itemsOnSale = new MarketItem[](itemCount);
        for (uint256 i = 1; i <= totalItemCount; i++) {
            if (idToMarketItem[i].sold == false) {
                itemsOnSale[currentIndex] = idToMarketItem[i];
                currentIndex++;
            }
        }
        return itemsOnSale;
    }

    function getMyItemsOnSale(address sender) public view returns (MarketItem[] memory) {
        uint256 totalItemCount = saleCount;
        uint256 itemCount = 0;
        uint256 currentIndex = 0;

        for (uint256 i = 1; i <= totalItemCount; i++) {
            if (
                idToMarketItem[i].sold == false &&
                idToMarketItem[i].seller == sender
            ) {
                itemCount++;
            }
        }

        MarketItem[] memory myItemsOnSale = new MarketItem[](itemCount);
        for (uint256 i = 1; i <= totalItemCount; i++) {
            if (
                idToMarketItem[i].sold == false &&
                idToMarketItem[i].seller == sender
            ) {
                myItemsOnSale[currentIndex] = idToMarketItem[i];
                currentIndex++;
            }
        }
        return myItemsOnSale;
    }

    function delistItem(uint256 _itemId) public {
        address origin = _msgSender();
        require(_itemId != 0, "_itemId cannot be zero");
        MarketItem memory item = idToMarketItem[_itemId];
        require(item.sold == false, "Item is already sold");
        require(item.seller == origin, "You can't delist this item");
        if (item.isErc1155) {
            IERC1155(item.nftToken).safeTransferFrom(
                address(this),
                item.seller,
                item.tokenId,
                1,
                ""
            );
        } else {
            IERC721(item.nftToken).safeTransferFrom(
                address(this),
                item.seller,
                item.tokenId
            );
        }
        emit ItemDelist(
            item.itemId,
            item.nftToken,
            item.tokenId,
            item.seller,
            item.price,
            item.isErc1155
        );
        delete idToMarketItem[_itemId];
    }

    function onERC1155Received(
        address,
        address,
        uint256,
        uint256,
        bytes memory
    ) public virtual override returns (bytes4) {
        return this.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(
        address,
        address,
        uint256[] memory,
        uint256[] memory,
        bytes memory
    ) public virtual override returns (bytes4) {
        return this.onERC1155BatchReceived.selector;
    }

    function onERC721Received(
        address,
        address,
        uint256,
        bytes memory
    ) public virtual returns (bytes4) {
        return this.onERC721Received.selector;
    }
}
