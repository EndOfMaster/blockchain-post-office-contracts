// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "./interfaces/IERC721.sol";

contract PostOffice is ERC721Holder, ERC1155Holder {
    uint8 public constant ERC20_TYPE = 1;
    uint8 public constant ERC721_TYPE = 2;
    uint8 public constant ERC1155_TYPE = 3;

    bytes4 public constant ERC721_ID = 0x80ac58cd;
    bytes4 public constant ERC1155_ID = 0xd9b67a26;

    struct Annex {
        uint8 _type;
        address _address;
        uint256 _amount;
        uint256[] _ids;
    }

    struct PayInfo {
        address _token;
        uint256 _amount;
    }

    struct Letter {
        address _sender;
        address _receiver;
        Annex[] _annex;
        PayInfo _payInfo;
        uint256 _deadline;
    }

    mapping(bytes32 => Letter) public letter;

    function sendLetter(Annex[] memory _annex, PayInfo memory _payInfo, uint256 _deadline) external returns (bytes32) {}

    function claim(bytes32 _id) external {}

    function checkERC721Type(address _address) public view returns (bool) {
        return IERC721(_address).supportsInterface(ERC721_ID);
    }

    function checkERC1155Type(address _address) public view returns (bool) {
        return IERC721(_address).supportsInterface(ERC1155_ID);
    }

    function buildId(Annex[] memory _annex, PayInfo memory _payInfo, uint256 _deadline) public view returns (bytes32) {
        return keccak256(abi.encode(_annex, _payInfo, _deadline, block.prevrandao, block.timestamp));
    }

    receive() external payable {}
}
