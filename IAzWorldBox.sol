// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";

interface IAzWorldBox is IERC1155 {
    function burn(
        address account,
        uint256 id,
        uint256 value
    ) external;

    function balanceOf(address account, uint256 id)
        external
        view override
        returns (uint256);

    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes calldata data
    ) external override;
    function mint(
        address _to,
        uint256 _boxType,
        uint256 _amount
    ) external;
}
