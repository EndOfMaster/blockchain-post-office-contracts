// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "../interface/IBlast.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

interface IERC20Rebasing {
    // changes the yield mode of the caller and update the balance
    // to reflect the configuration
    function configure(YieldMode) external returns (uint256);

    // "claimable" yield mode accounts can call this this claim their yield
    // to another address
    function claim(address recipient, uint256 amount) external returns (uint256);

    // read the claimable amount for an account
    function getClaimableAmount(address account) external view returns (uint256);
}

contract BlastReward is OwnableUpgradeable {
    address public constant BLAST_YIELD = 0x4300000000000000000000000000000000000002;

    // NOTE: these addresses will be slightly different on the Blast mainnet
    IERC20Rebasing public constant USDB = IERC20Rebasing(0x4200000000000000000000000000000000000022);
    IERC20Rebasing public constant WETH = IERC20Rebasing(0x4200000000000000000000000000000000000023);

    function initialize() public virtual {
        USDB.configure(YieldMode.CLAIMABLE); //configure claimable yield for USDB
        WETH.configure(YieldMode.CLAIMABLE); //configure claimable yield for WETH
        IBlast(BLAST_YIELD).configureClaimableYield();
        IBlast(BLAST_YIELD).configureClaimableGas();
    }

    constructor() {
        initialize();
    }

    function claimYield(address recipient, uint256 amount) external onlyOwner {
        //This function is public meaning anyone can claim the yield
        IBlast(BLAST_YIELD).claimYield(address(this), recipient, amount);
    }

    function claimAllYield(address recipient) external onlyOwner {
        //This function is public meaning anyone can claim the yield
        IBlast(BLAST_YIELD).claimAllYield(address(this), recipient);
    }

    function claimMyContractsGas() external onlyOwner {
        IBlast(BLAST_YIELD).claimAllGas(address(this), msg.sender);
    }
}
