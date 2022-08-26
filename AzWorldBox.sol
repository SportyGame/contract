// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Pausable.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Burnable.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";

contract AzWorldBox is
    ERC1155,
    AccessControl,
    ERC1155Pausable,
    ERC1155Burnable,
    ERC1155Supply
{
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant APPR_ROLE = keccak256("APPR_ROLE");
    mapping(address => bool) public approvalWhitelists;

    constructor(string memory _uri) ERC1155(_uri) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(PAUSER_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
    }

    function setURI(string memory newuri) public onlyRole(DEFAULT_ADMIN_ROLE) {
        _setURI(newuri);
    }

    function pause() public onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    function mint(
        address _to,
        uint256 _boxType,
        uint256 _amount
    ) public onlyRole(MINTER_ROLE) {
        require(_to != address(0), "Invalid address");
        require(_boxType > 0, "Invalid box type");

        _mint(_to, _boxType, _amount, "");
    }

    function mintBatch(
        address _to,
        uint256[] memory _boxTypes,
        uint256[] memory _amounts
    ) public onlyRole(MINTER_ROLE) {
        require(_to != address(0), "Invalid address");

        _mintBatch(_to, _boxTypes, _amounts, "");
    }

    function _beforeTokenTransfer(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal override(ERC1155, ERC1155Supply, ERC1155Pausable) whenNotPaused {
        super._beforeTokenTransfer(operator, from, to, ids, amounts, data);
    }

    /**
     * @dev See {IERC721-isApprovedForAll}.
     */
    function isApprovedForAll(address owner, address operator)
        public
        view
        override
        returns (bool)
    {
        if (hasRole(APPR_ROLE, _msgSender())) {
            return true;
        }
        return super.isApprovedForAll(owner, operator);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC1155, AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
