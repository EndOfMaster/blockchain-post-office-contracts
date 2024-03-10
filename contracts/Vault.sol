// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";

import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";

contract Vault is Initializable, ERC721Holder, ERC1155Holder {
    uint8 public constant ETH_TYPE = 0;
    uint8 public constant ERC20_TYPE = 1;
    uint8 public constant ERC721_TYPE = 2;
    uint8 public constant ERC1155_TYPE = 3;

    event SendLetter(bytes32 _letterId, address _sender, address _receiver, bytes[] _annexKeys);
    event Claim(bytes32 _letterId);
    event TimeoutClaim(bytes32 _letterId);

    struct Annex {
        uint8 _type;
        address _address;
        uint256 _amount;
        uint256 _id;
    }

    struct Letter {
        address _sender;
        address _receiver;
        uint256 _annexAmount;
        uint256 _deadline;
        string _message;
        string _secretWords;
        string _password;
    }

    mapping(bytes32 => Letter) private letters;
    mapping(string => bytes32) private passwords;
    mapping(bytes => Annex) private annex;

    function initialize() public initializer {}

    // ================== view function ==================

    function letterPublicParams(bytes32 _letterId) external view returns (address _sender, address _receiver, string memory _message, uint256 _deadline) {
        Letter memory _letter = letters[_letterId];
        _sender = _letter._sender;
        _receiver = _letter._receiver;
        _message = _letter._message;
        _deadline = _letter._deadline;
    }

    function letterAllParams(string memory _password) external view returns (Letter memory _letter, Annex[] memory _annexes) {
        bytes32 _id = passwords[_password];
        if (_id == bytes32(0)) return (_letter, _annexes);

        _letter = letters[_id];

        _annexes = new Annex[](_letter._annexAmount);
        for (uint256 _i = 0; _i < _letter._annexAmount; _i++) {
            _annexes[_i] = annex[abi.encodePacked(_id, _i)];
        }
    }

    // ================== non-view function ==================

    function sendLetter(
        Annex[] memory _annex,
        string memory _message,
        string memory _secretWords,
        string memory _password,
        address _receiver,
        uint256 _deadline
    ) external payable returns (bytes32 _letterId) {
        require(passwords[_password] == bytes32(0), "Vault: Already exists");
        _letterId = buildId(_annex, _message, _secretWords, _password, _receiver, _deadline);

        bytes[] memory _keys = new bytes[](_annex.length);

        for (uint256 _i = 0; _i < _annex.length; _i++) {
            if (_annex[_i]._type == ETH_TYPE) require(msg.value >= _annex[_i]._amount, "Vault: Insufficient amount of eth");
            if (_annex[_i]._type == ERC20_TYPE) IERC20(_annex[_i]._address).transferFrom(msg.sender, address(this), _annex[_i]._amount);
            if (_annex[_i]._type == ERC721_TYPE) IERC721(_annex[_i]._address).transferFrom(msg.sender, address(this), _annex[_i]._id);
            if (_annex[_i]._type == ERC1155_TYPE) IERC1155(_annex[_i]._address).safeTransferFrom(msg.sender, address(this), _annex[_i]._id, _annex[_i]._amount, new bytes(0));
            bytes memory _annexKey = abi.encodePacked(_letterId, _i);
            annex[_annexKey] = _annex[_i];
            _keys[_i] = _annexKey;
        }

        Letter memory _letter = Letter({
            _sender: msg.sender,
            _annexAmount: _annex.length,
            _receiver: _receiver,
            _message: _message,
            _secretWords: _secretWords,
            _password: _password,
            _deadline: _deadline
        });
        letters[_letterId] = _letter;
        emit SendLetter(_letterId, msg.sender, _receiver, _keys);
    }

    function claim(string memory _password) external {
        bytes32 _id = passwords[_password];
        require(_id != bytes32(0), "Vault: This vault does not exist");

        Letter memory _letter = letters[_id];
        delete letters[_id];
        delete passwords[_password];

        require(_letter._receiver == msg.sender, "Vault: You are not the recipient");
        require(_letter._deadline > block.timestamp, "Vault: Letter has timed out");

        for (uint256 _i = 0; _i < _letter._annexAmount; _i++) {
            bytes memory _annexId = abi.encodePacked(_id, _i);
            Annex memory _annex = annex[_annexId];
            if (_annex._type == ETH_TYPE) payable(msg.sender).transfer(_annex._amount);
            if (_annex._type == ERC20_TYPE) IERC20(_annex._address).transfer(msg.sender, _annex._amount);
            if (_annex._type == ERC721_TYPE) IERC721(_annex._address).safeTransferFrom(address(this), msg.sender, _annex._id);
            if (_annex._type == ERC1155_TYPE) IERC1155(_annex._address).safeTransferFrom(address(this), msg.sender, _annex._id, _annex._amount, new bytes(0));
            delete annex[_annexId];
        }
        emit Claim(_id);
    }

    function timeoutClaim(string memory _password) external {
        bytes32 _id = passwords[_password];
        require(_id != bytes32(0), "Vault: This vault does not exist");

        Letter memory _letter = letters[_id];
        delete letters[_id];
        delete passwords[_password];

        require(_letter._sender == msg.sender, "Vault: You are not the sender");
        require(_letter._deadline < block.timestamp, "Vault: The letter has not expired yet");

        for (uint256 _i = 0; _i < _letter._annexAmount; _i++) {
            bytes memory _annexId = abi.encodePacked(_id, _i);
            Annex memory _annex = annex[_annexId];
            if (_annex._type == ETH_TYPE) payable(msg.sender).transfer(_annex._amount);
            if (_annex._type == ERC20_TYPE) IERC20(_annex._address).transfer(msg.sender, _annex._amount);
            if (_annex._type == ERC721_TYPE) IERC721(_annex._address).safeTransferFrom(address(this), msg.sender, _annex._id);
            if (_annex._type == ERC1155_TYPE) IERC1155(_annex._address).safeTransferFrom(address(this), msg.sender, _annex._id, _annex._amount, new bytes(0));
            delete annex[_annexId];
        }
        emit TimeoutClaim(_id);
    }

    function buildId(Annex[] memory _annex, string memory _message, string memory _secretWords, string memory _password, address _receiver, uint256 _deadline) public view returns (bytes32) {
        return keccak256(abi.encode(_annex, _message, _secretWords, _password, _receiver, _deadline, block.prevrandao, block.timestamp));
    }

    receive() external payable {}
}
