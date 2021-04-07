// SPDX-License-Identifier: MIT
pragma solidity  >=0.6.8;

import "@pancakeswap/pancake-swap-lib/contracts/token/BEP20/BEP20.sol";

// ShitToken with Governance.
contract ShitToken is BEP20('Shit Token', 'SHIT') {

    // Address of the farming contract
    address public farmAddress;

    modifier onlyFarm() {
        require(farmAddress == msg.sender, 'Only Farm: caller is not the farm');
        _;
    }

    /// @notice Creates `_amount` token to `_to`. Must only be called by the owner (MasterChef).
    function mint(address _to, uint256 _amount) public onlyFarm {
        _mint(_to, _amount);
    }

    // Set the farming contract
    function setFarm (address _farm) public onlyOwner {
        require(address(0) != _farm, 'SHIT: Farm cannot be 0 address');
        farmAddress = _farm;
    }

    /// @notice A record of states for signing / validating signatures
    mapping (address => uint) public nonces;
}