// SPDX-License-Identifier: MIT
pragma solidity  >=0.8.3;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

// ShitToken with Governance.
contract ShitToken is ERC20('Shit Token', 'SHIT'), Ownable {

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