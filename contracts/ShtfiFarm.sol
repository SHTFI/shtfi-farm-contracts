// SPDX-License-Identifier: MIT
pragma solidity >=0.8.3;

import '@openzeppelin/contracts/utils/math/SafeMath.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import '@openzeppelin/contracts/access/Ownable.sol';

import "./ShtfiToken.sol";

/**
    This contract controls all farms which farm SHTFI and mints new SHTFI on each block.

    Ths contract is ownable and will be transferred to a DAO should the project takeoff
 */
contract ShtfiFarm is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    // Info of each user.
    struct UserInfo {
        uint256 amount;         // How many tokens has the user staked.
        uint256 totalRewards;   // Record of the current user's total rewards
        uint256 lastClaim;       // Block of the user's last clam
    }

    // Info of each farm.
    struct FarmInfo {
        IERC20 stakedToken;         // Address of the staked token contract
        uint256 stakedBalance;      // Get farm's balance of staked tokens -- So staked SHTFI isn't mix with rewarded SHTFI
        uint256 allocPoint;         // How many allocation points assigned to this farm. SHTFI to distribute per block.
        uint256 startBlock;         // The block which the farm's mining starts
        uint256 rewardAlloc;          // The amount of SHTFI allocated to the farm
        uint256 rewardPerBlock;       // The amount of SHTFI per block this farm receives
        uint256 lastRewardBlock;    // Last block the farm received rewards on
    }

    // The SHTFI TOKEN!
    ShtfiToken public shtfi;
    // Dev address.
    address public devAddr;
    // SHTFI tokens created per block.
    uint256 public rewardPerBlock;
    // Bonus multiplier for early SHTFI makers.
    uint256 public BONUS_MULTIPLIER = 1;
    // Info of each farm.
    FarmInfo[] public farmInfo;
    // Get farm ID from address
    mapping(address => uint) public farmId;
    // Info of each user that stakes tokens.
    mapping (uint256 => mapping (address => UserInfo)) public userInfo;
    // Total allocation points. Must be the sum of all allocation points in all farms.
    uint256 public totalAllocPoint = 0;
    // Is the contract locked?
    bool public currentlyActive = true;

    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event ClaimRewards(address indexed user, uint256 indexed pid, uint256 amount);
    event EmergencyWithdraw(address indexed user, uint256 indexed pid, uint256 amount);

    constructor(
        ShtfiToken _shtfi,
        uint256 _rewardPerBlock,
        uint256 _startBlock
    ) {
        shtfi = _shtfi;
        devAddr = msg.sender;
        rewardPerBlock = _rewardPerBlock;

        // Initial staking farm
        farmInfo.push(FarmInfo({
            stakedToken: _shtfi,
            allocPoint: 100,
            stakedBalance: 0,
            startBlock: _startBlock,
            rewardAlloc: 0,
            rewardPerBlock: 0,
            lastRewardBlock: _startBlock
        }));
        farmId[address(this)] = 0;
        totalAllocPoint = 100;
    }

    modifier onlyActive () {
        require(currentlyActive == true, "ERROR: FARMING PAUSED");
        _;
    }

    function updateMultiplier(uint256 multiplierNumber) public onlyOwner {
        BONUS_MULTIPLIER = multiplierNumber;
    }

    function farmLength() public view returns (uint256) {
        return farmInfo.length;
    }

    function getFarmId(address _farm) public view returns (uint256) {
        return farmId[address(_farm)];
    }

    // Add a new staking farm. Can only be called by the owner
    function add(uint256 _allocPoint, IERC20 _stakedToken, uint256 _startBlock, bool _withUpdate) public onlyOwner {
        if (_withUpdate) {
            massUpdateFarms();
        }
        farmInfo.push(FarmInfo({
            stakedToken: _stakedToken,
            allocPoint: _allocPoint,
            stakedBalance: 0,
            startBlock: _startBlock,
            rewardAlloc: 0,
            rewardPerBlock:0,
            lastRewardBlock: _startBlock
        }));
        uint totalFarms = farmLength();
        farmId[address(_stakedToken)] = totalFarms.sub(1);
        totalAllocPoint = totalAllocPoint.add(_allocPoint);
    }

    // Update the given farm's SHTFI allocation point. Can only be called by the owner.
    function set(uint256 _pid, uint256 _allocPoint, bool _withUpdate) public onlyOwner {
        if (_withUpdate) {
            massUpdateFarms();
        }
        uint256 prevAllocPoint = farmInfo[_pid].allocPoint;
        farmInfo[_pid].allocPoint = _allocPoint;
        if (prevAllocPoint != _allocPoint) {
            totalAllocPoint = totalAllocPoint.sub(prevAllocPoint).add(_allocPoint);
        }
    }

    // Internal function to get pending rewards of a user
    function _pendingReward(
        uint256 _farmStakedBalance,
        uint256 _farmRewardPerBlock,
        uint256 _userBalance,
        uint256 _userClaimableBlocks
        ) internal pure returns(uint256) {
        uint256 pending = _farmRewardPerBlock.mul(_userClaimableBlocks).mul(_userBalance).div(_farmStakedBalance);
        return pending;
    }

    // View function to see pending SHTFI on frontend.
    function pendingReward(uint256 _pid, address _user) external view returns (uint256) {
        FarmInfo storage farm = farmInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        // If there isn't any staked balance there cant be any rewards
        if ( farm.stakedBalance == 0 ) {
            return 0;
        }
        uint256 _claimableBlocks = block.number.sub(user.lastClaim == 0 ? farm.startBlock : user.lastClaim);
        uint256 pending = _pendingReward(farm.stakedBalance, farm.rewardPerBlock, user.amount, _claimableBlocks);
        return pending;
    }

    // Update reward variables for all farms. Be careful of gas spending!
    function massUpdateFarms() public {
        uint256 length = farmInfo.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            updateFarm(pid);
        }
    }

    function _mintFarmBlockReward(uint256 _amountToMint) private {
        // Mint the correct amount of SHTFI for the farm which caused the function to be called
        shtfi.mint(address(this), _amountToMint.mul(BONUS_MULTIPLIER));
    }

    // Update reward variables of the given farm to be up-to-date.
    function updateFarm(uint256 _pid) public onlyActive {
        FarmInfo storage farm = farmInfo[_pid];
        // Has the farm started earning yet?
        if ( block.number <= farm.lastRewardBlock) {
            return;
        }
        // blocks passed since last reward for this farm
        uint256 blocksPassed = block.number.sub(farm.lastRewardBlock);
        // Block Reward for all farms
        uint256 blockReward = blocksPassed.mul(rewardPerBlock);
        // Block reward for the current farm
        uint256 blockRewardForFarm = blockReward.mul(farm.allocPoint).div(totalAllocPoint);
        // Set the amount of SHTFI this farm will receive per block
        farm.rewardPerBlock = rewardPerBlock.mul(farm.allocPoint).div(totalAllocPoint);
        // Mint SHTFI if there is any
        if ( blockRewardForFarm > 0 ) {
            // Mint the block reward for this farm
            _mintFarmBlockReward(blockRewardForFarm);
            // Update the current farm's allocation of SHTFI
            farm.rewardAlloc = farm.rewardAlloc.add(blockRewardForFarm);
            // Update the last reward block for this farm
            farm.lastRewardBlock = block.number;
        }
    }

    // Deposit LP tokens to contract for SHTFI allocation.
    function deposit(uint256 _pid, uint256 _amount) public onlyActive {
        // Get the farm object
        FarmInfo storage farm = farmInfo[_pid];
        // Check the farm is open before we allow deposits
        if ( block.number < farm.startBlock ) {
            return;
        }
        UserInfo storage user = userInfo[_pid][msg.sender];
        // if user's first interaction with farm
        if (user.lastClaim == 0 ) {
            // Their first claimable block is the start block
            user.lastClaim = block.number;
        }
        // Update the farm
        updateFarm(_pid);
        // Claim rewards if user is invested
        if (user.amount > 0) {
            uint256 _claimableBlocks = block.number.sub(user.lastClaim == 0 ? farm.startBlock : user.lastClaim);
            uint256 pending = _pendingReward(farm.stakedBalance, farm.rewardPerBlock, user.amount, _claimableBlocks);
            // Check if pending balance is more than 0
            if(pending > 0) {
                // Update user's total rewards
                user.totalRewards = user.totalRewards.add(pending);
                // Update the last claim of the user to prevent double claim;
                user.lastClaim = block.number;
                // Transfer rewards
                safeRewardTransfer(msg.sender, pending);
                // Update farm's SHTFI balance
                farm.rewardAlloc = farm.rewardAlloc.sub(pending);
                // Emit claim event
                emit ClaimRewards(msg.sender, _pid, pending);
            }
        }
        // Has the user actually deposited?
        if (_amount > 0) {
            // Transfer their tokens to this address
            farm.stakedToken.safeTransferFrom(address(msg.sender), address(this), _amount);
            // Update the user object
            user.amount = user.amount.add(_amount);
            // Update farm object
            farm.stakedBalance = farm.stakedBalance.add(_amount);
        }
        emit Deposit(msg.sender, _pid, _amount);
    }

    // Withdraw staked tokens from from our contract.
    function withdraw(uint256 _pid, uint256 _amount) public {
        FarmInfo storage farm = farmInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        // Ensure the user is not trying to withdraw more than they have deposited.
        require(user.amount >= _amount, "SHIT FARM: Not enough staked");
        // Update the farm if mining is currently active
        if (currentlyActive == true ) {
            // Update the farm
            updateFarm(_pid);
        }
       // Claim rewards if user is invested
        if (user.amount > 0 && user.lastClaim < block.number) {
            uint256 _claimableBlocks = block.number.sub(user.lastClaim == 0 ? farm.startBlock : user.lastClaim);
            uint256 pending = _pendingReward(farm.stakedBalance, farm.rewardPerBlock, user.amount, _claimableBlocks);
            // Check if pending balance is more than 0
            if(pending > 0) {
                // Update user's total rewards
                user.totalRewards = user.totalRewards.add(pending);
                // Update the last claim of the user to prevent double claim;
                user.lastClaim = block.number;
                // Transfer rewards
                safeRewardTransfer(msg.sender, pending);
                // Update farm's SHTFI balance
                farm.rewardAlloc = farm.rewardAlloc.sub(pending);
                // Emit claim event
                emit ClaimRewards(msg.sender, _pid, pending);
            }
        }
        // Check the amount to withdraw
        if(_amount > 0) {
            // Update user object
            user.amount = user.amount.sub(_amount);
            // Transfer user's tokens back to them
            farm.stakedToken.safeTransfer(address(msg.sender), _amount);
            // Update farm object
            farm.stakedBalance = farm.stakedBalance.sub(_amount);
            // If user is withdrawing their entire stake reset their block counter
            if ( user.amount == 0 ) {
                user.lastClaim = 0;
            }
        }

        emit Withdraw(msg.sender, _pid, _amount);
    }

    // Withdraw without caring about rewards. EMERGENCY ONLY.
    function emergencyWithdraw(uint256 _pid) public {
        FarmInfo storage farm = farmInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        farm.stakedToken.safeTransfer(address(msg.sender), user.amount);
        emit EmergencyWithdraw(msg.sender, _pid, user.amount);
        user.amount = 0;
    }

    // Safe SHTFI transfer function, just in case if rounding error causes farm to not have enough SHTFI.
    function safeRewardTransfer(address _to, uint256 _amount) internal {
        shtfi.transfer(_to, _amount);
    }

    function endMining () public onlyOwner {
        // Update all the farms before we end mining so that user rewards are up to date
        massUpdateFarms();
        // End the mining period
        currentlyActive = false;
    }

    // Update dev address by the previous dev.
    function dev(address _devAddr) public {
        require(msg.sender == devAddr, "dev: wut?");
        devAddr = _devAddr;
    }

    // Allows owner to change block reward
    function setRewardPerBlock (uint256 _rewardPerBlock) public onlyOwner {
        rewardPerBlock = _rewardPerBlock;
    }

    // Allows dev to set a new farm contract which can mint SHTFI
    // Some safe guards have been taken but an element of trust is required as long as this
    // exists. Ideally we need a DAO to be placed here which will allow the community
    // to have complete control of the SHTFI token.
    // An option to get around this is by capping the total supply of SHTFI.
    function migrateRewardToken (address _newFarm) public onlyOwner {
        require(_newFarm != msg.sender, "ERROR: ADDRESS SHOULD BE NEW FARM");
        require(_newFarm != devAddr, "ERROR: ADDRESS SHOULD BE NEW FARM");
        shtfi.setFarm(_newFarm);
    }
}