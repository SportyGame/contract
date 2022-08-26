// SPDX-License-Identifier: MIT

pragma solidity >=0.8.4;
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract AzWorldNFT is
    ERC721,
    ERC721Enumerable,
    ERC721URIStorage,
    Pausable,
    AccessControl
{
    string public baseExtension = ".json";
    using Strings for uint256;
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant APPR_ROLE = keccak256("APPR_ROLE");
    bool public revealed = false;
    string public notRevealedUri;
    string public baseTokenURI;
    struct NftWithType{
        uint256 _tokenId;
        uint256 _type;
    }
    mapping(uint256 => uint256) public nftType;

    uint256 public TotalSupply = 10000;
    uint256 public mintedNFT;

    constructor(string memory _bUri) ERC721("AzWorld NFT", "AZWNFT") {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(PAUSER_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
        baseTokenURI = _bUri;
        notRevealedUri = _bUri;
    }

    function getRarity(uint256 tokenId) external view returns(uint256){
        return nftType[tokenId];
    }

    function _baseURI() internal view override returns (string memory) {
        return baseTokenURI;
    }

    function setBaseUri(string memory _newBaseUri) external onlyRole(DEFAULT_ADMIN_ROLE) {
        baseTokenURI = _newBaseUri;
    }
    function tokenURI(uint256 tokenId)
        public
        view
        virtual
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        require(
            _exists(tokenId),
            "ERC721Metadata: URI query for nonexistent token"
        );

        if (revealed == false) {
            return notRevealedUri;
        }

        string memory currentBaseURI = _baseURI();
        return
            bytes(currentBaseURI).length > 0
                ? string(
                    abi.encodePacked(
                        currentBaseURI,
                        tokenId.toString(),
                        baseExtension
                    )
                )
                : "";
    }
    //only owner
    function reveal() public onlyRole(DEFAULT_ADMIN_ROLE) {
        revealed = true;
    }

    function setNotRevealedURI(string memory _notRevealedURI) public onlyRole(DEFAULT_ADMIN_ROLE) {
        notRevealedUri = _notRevealedURI;
    }

    function pause() public onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    function safeMint(address _to, uint256 _nftType)
        public
        onlyRole(MINTER_ROLE)
    {
        mintedNFT++;
        require(mintedNFT <= TotalSupply,"Max supply reached");
        nftType[mintedNFT] = _nftType;
        _safeMint(_to, mintedNFT);
    }

    function tokensOfOwner(address owner)
        public
        view
        returns (NftWithType[] memory)
    {

        uint256 balance = balanceOf(owner);
        NftWithType[] memory nftArray = new NftWithType[](balance);

        for (uint256 i = 0; i < balance; i++) {
            uint256 tokenId = tokenOfOwnerByIndex(owner, i);
            nftArray[i]._tokenId = tokenId;
            nftArray[i]._type = nftType[tokenId];
        }

        return nftArray;
    }

    function burn(uint256 tokenId) external {
        require(
            _isApprovedOrOwner(_msgSender(), tokenId),
            "Only approved or owner can burn token"
        );
        _burn(tokenId);
    }

    function _burn(uint256 tokenId)
        internal
        override(ERC721, ERC721URIStorage)
    {
        super._burn(tokenId);
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal override(ERC721, ERC721Enumerable) whenNotPaused {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable, AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    function isApprovedForAll(address owner, address operator)
        public
        view
        override(ERC721)
        returns (bool)
    {
        if (hasRole(APPR_ROLE, _msgSender())) {
            return true;
        }
        return super.isApprovedForAll(owner, operator);
    }
}