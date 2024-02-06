// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";

import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";

contract PostOffice is Initializable, ERC721Holder, ERC1155Holder {
    uint8 public constant ERC20_TYPE = 1;
    uint8 public constant ERC721_TYPE = 2;
    uint8 public constant ERC1155_TYPE = 3;

    bytes4 public constant ERC721_ID = 0x80ac58cd;
    bytes4 public constant ERC1155_ID = 0xd9b67a26;

    event SendLetter(bytes32 _letterId, address _sender, address _receiver);
    event Claim(bytes32 _letterId);
    event TimeoutClaim(bytes32 _letterId);

    struct Annex {
        uint8 _type;
        address _address;
        uint256 _amount;
        uint256 _id;
    }

    struct PayInfo {
        address _token;
        uint256 _amount;
    }

    struct Letter {
        address _sender;
        address _receiver;
        uint256 _annexAmount;
        PayInfo _payInfo;
        uint256 _deadline;
    }

    mapping(bytes32 => Letter) public letters;
    mapping(bytes => Annex) annex;

    function initialize() public initializer {}

    function sendLetter(Annex[] memory _annex, PayInfo memory _payInfo, address _receiver, uint256 _deadline) external returns (bytes32 _letterId) {
        _letterId = buildId(_annex, _payInfo, _receiver, _deadline);

        for (uint256 _i = 0; _i < _annex.length; _i++) {
            if (_annex[_i]._type == 1) IERC20(_annex[_i]._address).transferFrom(msg.sender, address(this), _annex[_i]._amount);
            if (_annex[_i]._type == 2) IERC721(_annex[_i]._address).transferFrom(msg.sender, address(this), _annex[_i]._id);
            if (_annex[_i]._type == 3) IERC1155(_annex[_i]._address).safeTransferFrom(msg.sender, address(this), _annex[_i]._id, _annex[_i]._amount, new bytes(0));
            annex[abi.encodePacked(_letterId, _i)] = _annex[_i];
        }

        Letter memory _letter = Letter({ _sender: msg.sender, _annexAmount: _annex.length, _receiver: _receiver, _payInfo: _payInfo, _deadline: _deadline });
        letters[_letterId] = _letter;
        emit SendLetter(_letterId, msg.sender, _receiver);
    }

    function claim(bytes32 _id) external {
        Letter memory _letter = letters[_id];
        delete letters[_id];

        require(_letter._sender == address(0), "PostOffice: The letter does not exist");
        require(_letter._receiver == msg.sender, "PostOffice: You are not the recipient");
        require(_letter._deadline <= block.timestamp, "PostOffice: Letter has timed out");

        IERC20(_letter._payInfo._token).transferFrom(msg.sender, _letter._sender, _letter._payInfo._amount);

        for (uint256 _i = 0; _i < _letter._annexAmount; _i++) {
            bytes memory _annexId = abi.encodePacked(_id, _i);
            Annex memory _annex = annex[_annexId];
            if (_annex._type == 1) IERC20(_annex._address).transfer(msg.sender, _annex._amount);
            if (_annex._type == 2) IERC721(_annex._address).safeTransferFrom(address(this), msg.sender, _annex._id);
            if (_annex._type == 3) IERC1155(_annex._address).safeTransferFrom(address(this), msg.sender, _annex._id, _annex._amount, new bytes(0));
            delete annex[_annexId];
        }
        emit Claim(_id);
    }

    function timeoutClaim(bytes32 _id) external {
        Letter memory _letter = letters[_id];
        delete letters[_id];

        require(_letter._sender == address(0), "PostOffice: The letter does not exist");
        require(_letter._sender == msg.sender, "PostOffice: You are not the sender");
        require(_letter._deadline > block.timestamp, "PostOffice: The letter has not expired yet");

        for (uint256 _i = 0; _i < _letter._annexAmount; _i++) {
            bytes memory _annexId = abi.encodePacked(_id, _i);
            Annex memory _annex = annex[_annexId];
            if (_annex._type == 1) IERC20(_annex._address).transfer(msg.sender, _annex._amount);
            if (_annex._type == 2) IERC721(_annex._address).safeTransferFrom(address(this), msg.sender, _annex._id);
            if (_annex._type == 3) IERC1155(_annex._address).safeTransferFrom(address(this), msg.sender, _annex._id, _annex._amount, new bytes(0));
            delete annex[_annexId];
        }
        emit TimeoutClaim(_id);
    }

    function buildId(Annex[] memory _annex, PayInfo memory _payInfo, address _receiver, uint256 _deadline) public view returns (bytes32) {
        return keccak256(abi.encode(_annex, _payInfo, _receiver, _deadline, block.prevrandao, block.timestamp));
    }

    receive() external payable {}
}
