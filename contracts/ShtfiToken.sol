// SPDX-License-Identifier: MIT
pragma solidity  >=0.8.3;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import '@openzeppelin/contracts/utils/math/SafeMath.sol';

// ShitToken with Governance.
contract ShtfiToken is ERC20('SHTFI Token', 'SHTFI'), Ownable {

    using SafeMath for uint256;

    // Address of the farming contract
    address public farmAddress;

    // Maximum SHTFI tokens which will ever exist
    uint256 public maxSupply = 222222222222222222222222;

    modifier onlyFarm() {
        require(farmAddress == msg.sender, 'Only Farm: caller is not the farm');
        _;
    }

    /// @notice Creates `_amount` token to `_to`. Must only be called by the farm contract.
    function mint(address _to, uint256 _amount) public onlyFarm {
        uint256 _currentSupply = totalSupply();
        require(_currentSupply < maxSupply, 'ERROR: SUPPLY CAP MET');
        uint256 _toMint = _currentSupply.add(_amount) < maxSupply ? _amount : maxSupply.sub(totalSupply());
        _mint(_to, _toMint);
    }

    // Set the farming contract
    function setFarm (address _farm) public onlyOwner {
        require(address(0) != _farm, 'SHTFI: Farm cannot be 0 address');
        require(msg.sender != _farm, 'SHTFI: Farm cannot be owner address');
        farmAddress = _farm;
    }

    /// @notice A record of states for signing / validating signatures
    mapping (address => uint) public nonces;
}