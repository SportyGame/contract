// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

interface IAzWorldNFT is IERC721 {
    function safeMint(
        address _to,
        uint256 _nftType
    ) external;
    function mintedNFT() external view returns (uint256);
}
