// SPDX-License-Identifier: MIT
pragma solidity >=0.8.3;

import '@openzeppelin/contracts/utils/math/SafeMath.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import '@openzeppelin/contracts/access/Ownable.sol';

import "./ShitToken.sol";

/**
    ShitFarm is the master of shit.

    This contract controls all pools which farm shit and mints new SHIT on each block.

    Ths contract is ownable and will be transferred fto a DAO should the project takeoff
 */
contract ShitFarm is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    // Info of each user.
    struct UserInfo {
        uint256 amount;         // How many tokens has the user staked.
        uint256 totalRewards;   // Record of the current user's total rewards
        uint256 lastClaim;       // Block of the user's last clam
    }

    // Info of each pool.
    struct PoolInfo {
        IERC20 stakedToken;         // Address of the staked token contract
        uint256 stakedBalance;      // Get pool's balance of staked tokens -- So staked shit isn't mix with rewarded shit
        uint256 allocPoint;         // How many allocation points assigned to this pool. SHITs to distribute per block.
        uint256 startBlock;         // The block which the pool's mining starts
        uint256 shitAlloc;          // The about of SHIT allocated to the pool
        uint256 shitPerBlock;       // The amount of shit per block this pool receives
        uint256 lastRewardBlock;    // Last block the pool received rewards on
    }

    // The SHIT TOKEN!
    ShitToken public shit;
    // Last block number that SHITs distribution occurs.
    uint256 public lastRewardBlock;
    // Dev address.
    address public devAddr;
    // SHIT tokens created per block.
    uint256 public shitPerBlock;
    // Bonus multiplier for early shit makers.
    uint256 public BONUS_MULTIPLIER = 1;
    // Amount of shit staked in the shit pool
    uint256 public totalShitStaked;
    // Amount of SHIT each pool's allocation point is worth
    uint256 public shitPerAllocPoint;
    // Info of each pool.
    PoolInfo[] public poolInfo;
    // Info of each user that stakes tokens.
    mapping (uint256 => mapping (address => UserInfo)) public userInfo;
    // Total allocation points. Must be the sum of all allocation points in all pools.
    uint256 public totalAllocPoint = 0;

    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event ClaimRewards(address indexed user, uint256 indexed pid, uint256 amount);
    event EmergencyWithdraw(address indexed user, uint256 indexed pid, uint256 amount);

    constructor(
        ShitToken _shit,
        uint256 _shitPerBlock,
        uint256 _startBlock
    ) {
        shit = _shit;
        devAddr = msg.sender;
        shitPerBlock = _shitPerBlock;

        // Initial staking pool
        poolInfo.push(PoolInfo({
            stakedToken: _shit,
            allocPoint: 100,
            stakedBalance: 0,
            startBlock: _startBlock,
            shitAlloc: 0,
            shitPerBlock: 0,
            lastRewardBlock: _startBlock
        }));
        totalAllocPoint = 100;
    }

    function updateMultiplier(uint256 multiplierNumber) public onlyOwner {
        BONUS_MULTIPLIER = multiplierNumber;
    }

    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }

    // Add a new lp to the pool. Can only be called by the owner.
    // XXX DO NOT add the same LP token more than once. Rewards will be messed up if you do.
    function add(uint256 _allocPoint, IERC20 _stakedToken, uint256 _startBlock, bool _withUpdate) public onlyOwner {
        if (_withUpdate) {
            massUpdatePools();
        }
        poolInfo.push(PoolInfo({
            stakedToken: _stakedToken,
            allocPoint: _allocPoint,
            stakedBalance: 0,
            startBlock: _startBlock,
            shitAlloc: 0,
            shitPerBlock:0,
            lastRewardBlock: _startBlock
        }));
        totalAllocPoint = totalAllocPoint.add(_allocPoint);
    }

    // Update the given pool's SHIT allocation point. Can only be called by the owner.
    function set(uint256 _pid, uint256 _allocPoint, bool _withUpdate) public onlyOwner {
        if (_withUpdate) {
            massUpdatePools();
        }
        uint256 prevAllocPoint = poolInfo[_pid].allocPoint;
        poolInfo[_pid].allocPoint = _allocPoint;
        if (prevAllocPoint != _allocPoint) {
            totalAllocPoint = totalAllocPoint.sub(prevAllocPoint).add(_allocPoint);
        }
    }

    // Internal function to get pending Shit rewards
    function _pendingShit(
        uint256 _poolStakedBalance,
        uint256 _poolShitPerBlock,
        uint256 _userBalance,
        uint256 _userClaimableBlocks
        ) internal pure returns(uint256) {
        // If there isn't any staked balance there cant be any rewards
        if ( _poolStakedBalance == 0 ) {
            return 0;
        }
        uint256 pending = _poolShitPerBlock.mul(_userClaimableBlocks).mul(_userBalance).div(_poolStakedBalance);
        return pending;
    }

    // View function to see pending SHITs on frontend.
    function pendingShit(uint256 _pid, address _user) external view returns (uint256) {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        // If there isn't any staked balance there cant be any rewards
        if ( pool.stakedBalance == 0 ) {
            return 0;
        }
        uint256 _claimableBlocks = block.number.sub(user.lastClaim == 0 ? pool.startBlock : user.lastClaim);
        uint256 pending = _pendingShit(pool.stakedBalance, pool.shitPerBlock, user.amount, _claimableBlocks);
        return pending;
    }

    // Update reward variables for all pools. Be careful of gas spending!
    function massUpdatePools() public {
        uint256 length = poolInfo.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            updatePool(pid);
        }
    }

    function _mintPoolBlockReward(uint256 _totalBlockReward, uint256 _poolAllocPoints) private {
        // Mint the correct amount of SHIt for the pool which caused the function to be called
        shit.mint(address(this), _totalBlockReward.mul(_poolAllocPoints).div(totalAllocPoint));
    }

    // Update reward variables of the given pool to be up-to-date.
    function updatePool(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        // Has the pool started earning yet?
        if ( block.number <= pool.lastRewardBlock) {
            return;
        }
        // blocks passed since last reward for this pool
        uint256 blocksPassed = block.number.sub(pool.lastRewardBlock);
        // Block Reward
        uint256 blockReward = blocksPassed.mul(shitPerBlock);
        // available shit / total alloc
        uint256 shitInContract = shit.balanceOf(address(this));
        // SHIT staked in contract
        uint256 shitStaked = poolInfo[0].stakedBalance;
        // Amount of shit available for rewards in this pool
        uint256 availableShit = shitInContract.sub(shitStaked);
        // updated shit per allocation point
        shitPerAllocPoint = availableShit.add(blockReward).div(totalAllocPoint);
        // Set the amount of shit this pool will receive per block
        pool.shitPerBlock = shitPerBlock.mul(pool.allocPoint).div(totalAllocPoint);
        // Mint shit if there is any
        if ( blockReward > 0 ) {
            // Mint the block reward for this pool
            _mintPoolBlockReward(blockReward, pool.allocPoint);
            // Update the current pool's allocation of shit
            pool.shitAlloc = shitPerAllocPoint.mul(pool.allocPoint);
            // Update the last reward block for this pool
            pool.lastRewardBlock = block.number;
        }
    }

    // Deposit LP tokens to MasterChef for SHIT allocation.
    function deposit(uint256 _pid, uint256 _amount) public {
        // Get the pool object
        PoolInfo storage pool = poolInfo[_pid];
        // Check the pool is open before we allow deposits
        if ( block.number < pool.startBlock ) {
            return;
        }
        UserInfo storage user = userInfo[_pid][msg.sender];
        // if user's first interaction with pool
        if (user.lastClaim == 0 ) {
            // Their first claimable block is the start block
            user.lastClaim = block.number;
        }
        // Update the pool
        updatePool(_pid);
        // Claim rewards if user is invested
        if (user.amount > 0) {
            uint256 _claimableBlocks = block.number.sub(user.lastClaim == 0 ? pool.startBlock : user.lastClaim);
            uint256 pending = _pendingShit(pool.stakedBalance, pool.shitPerBlock, user.amount, _claimableBlocks);
            // Check if pending balance is more than 0
            if(pending > 0) {
                // Update user's total rewards
                user.totalRewards = user.totalRewards.add(pending);
                // Update the last claim of the user to prevent double claim;
                user.lastClaim = block.number;
                // Transfer rewards
                safeShitTransfer(msg.sender, pending);
                // Emit claim event
                emit ClaimRewards(msg.sender, _pid, pending);
            }
        }
        // Has the user actually deposited?
        if (_amount > 0) {
            // Transfer their tokens to this address
            pool.stakedToken.safeTransferFrom(address(msg.sender), address(this), _amount);
            // Update the user object
            user.amount = user.amount.add(_amount);
            // Update pool object
            pool.stakedBalance = pool.stakedBalance.add(_amount);
        }
        emit Deposit(msg.sender, _pid, _amount);
    }

    // Withdraw staked tokens from MasterChef.
    function withdraw(uint256 _pid, uint256 _amount) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        // Ensure the user is not trying to withdraw more than they have deposited.
        require(user.amount >= _amount, "SHIT FARM: Not enough staked");
        // Update the pool
        updatePool(_pid);
       // Claim rewards if user is invested
        if (user.amount > 0 && user.lastClaim < block.number) {
            uint256 _claimableBlocks = block.number.sub(user.lastClaim == 0 ? pool.startBlock : user.lastClaim);
            uint256 pending = _pendingShit(pool.stakedBalance, pool.shitPerBlock, user.amount, _claimableBlocks);
            // Check if oending balance is more than 0
            if(pending > 0) {
                // Update user's total rewards
                user.totalRewards = user.totalRewards.add(pending);
                // Update the last claim of the user to prevent double claim;
                user.lastClaim = block.number;
                // Transfer rewards
                safeShitTransfer(msg.sender, pending);
                // Emit claim event
                emit ClaimRewards(msg.sender, _pid, pending);
            }
        }
        // Check the amount to withdraw
        if(_amount > 0) {
            // Update user object
            user.amount = user.amount.sub(_amount);
            // Transfer user's tokens back to them
            pool.stakedToken.safeTransfer(address(msg.sender), _amount);
            // Update pool object
            pool.stakedBalance = pool.stakedBalance.sub(_amount);
            // If user is withdrawing their entire stake reset their block counter
            if ( user.amount == 0 ) {
                user.lastClaim = 0;
            }
        }

        emit Withdraw(msg.sender, _pid, _amount);
    }

    // Withdraw without caring about rewards. EMERGENCY ONLY.
    function emergencyWithdraw(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        pool.stakedToken.safeTransfer(address(msg.sender), user.amount);
        emit EmergencyWithdraw(msg.sender, _pid, user.amount);
        user.amount = 0;
    }

    // Safe shit transfer function, just in case if rounding error causes pool to not have enough SHITs.
    function safeShitTransfer(address _to, uint256 _amount) internal {
        shit.transfer(_to, _amount);
    }

    // Update dev address by the previous dev.
    function dev(address _devAddr) public {
        require(msg.sender == devAddr, "dev: wut?");
        devAddr = _devAddr;
    }
}