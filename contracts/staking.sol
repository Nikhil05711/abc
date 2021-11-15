


// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./NFT.sol";

contract staking is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for uint256;

// user have to stake the nft
    struct stake {
        uint256 amount;
        uint256 startingTime;
        uint256 rewardOut;
    }
// for multiple user where for a particular nft there is limit for every user how much he stake and a fixed amount is given beyond
//that no amount will be staked 
    struct stakePool {
        uint256 stakingLimit;
        uint256 stakingFixedAmount;
        uint256 rewardApply;
        uint256 startingTime;
        uint256 endTime;
        uint256 stakedTotal;
    }

    stakePool[] public stakePools;

    mapping(uint256 => mapping(address => stake)) public stakes;
    uint256[] public nftIds;
    mapping(address => uint256[]) public nftIdsPerAddress;
    address public stakeToken;
    NFT public nftToken;
    uint256 randNonce = 0;
    address public admin;

    constructor(address _stakeToken, address _nftAddress) {
        admin = msg.sender;
        require(_stakeToken != address(0), "Invalid Address found");
        stakeToken = _stakeToken;
        nftToken = NFT(_nftAddress);
    }

    event staked(uint256 poolId, uint256 amount);
    event RewardOut(uint256 pid, address staker, address token, uint256 amount);

    function addStakePool(
        uint256 _stakingLimit,
        uint256 _stakingFixedAmount,
        uint256 _rewardApply,
        uint256 _endTime
    ) public {
        stakePools.push(
            stakePool({
                stakingLimit: _stakingLimit,
                stakingFixedAmount: _stakingFixedAmount,
                rewardApply: _rewardApply,
                startingTime: block.timestamp,
                endTime: _endTime,
                stakedTotal: 0
            })
        );
    }

    function StakeNftToken(uint256 poolId, uint256 amount) public returns (bool) {
        require(
            amount == stakePools[poolId].stakingFixedAmount,
            "Inaproximate amount"
        );
        require(stakes[poolId][msg.sender].amount == 0, "Already staked");
        // require(
        //     block.timestamp >= stakePools[poolId].startingTime,
        //     "Bad timing request"
        // );
        require(
            block.timestamp < stakePools[poolId].endTime,
            "Bad timing request"
        );
        require(
            stakePools[poolId].stakedTotal.add(amount) <=
                stakePools[poolId].stakingLimit,
            "staking limit is over"
        );
        nftToken.transferPrice(msg.sender, stakeToken, amount);
        emit staked(poolId, amount);

        stakePools[poolId].stakedTotal = stakePools[poolId].stakedTotal.add(
            amount
        );
        stakes[poolId][msg.sender].amount = stakes[poolId][msg.sender]
            .amount
            .add(amount);
        stakes[poolId][msg.sender].startingTime = block.timestamp;
        stakes[poolId][msg.sender].rewardOut = 0;
        return true;
    }

    function withdraw(uint256 poolId) public returns (bool) {
        uint256 amount = stakes[poolId][msg.sender].amount;
        require(
            block.timestamp > stakePools[poolId].endTime,
            "bad timing request"
        );
        require(amount > 0, "Nothing to withdraw");
        genNewNftID(msg.sender);
        return withdrawWithoutReward(poolId, amount);
    }

    function genNewNftID(address to) public returns (bool) {
        uint256 nftId = rand();
        nftIds.push(nftId);
        nftIdsPerAddress[to].push(nftId);
        nftToken.mint(to, nftId);
        return true;
    }

    function withdrawWithoutReward(uint256 poolId, uint256 amount)
        public
        returns (bool)
    {
        return unstake(poolId, msg.sender, amount);
    }

    function unstake(
        uint256 poolId,
        address staker,
        uint256 amount
    ) public returns (bool) {
        require(amount > 0, "insufficient balance");
        require(
            amount <= stakes[poolId][msg.sender].amount,
            "Not enough balance to unstake token"
        );
        stakes[poolId][staker].amount = stakes[poolId][staker].amount.sub(
            amount
        );
        nftToken.transferPrice(stakeToken, staker, amount);
        return true;
    }

    function claim(uint256 poolId) internal returns (bool) {
        require(
            block.timestamp > stakePools[poolId].endTime,
            "bad timing request"
        );
        uint256 rewardAmount = currentReward(poolId, msg.sender);
        if (rewardAmount == 0) {
            return true;
        }
        nftToken.transferPrice(stakeToken, msg.sender, rewardAmount);
        emit RewardOut(poolId, msg.sender, stakeToken, rewardAmount);
        return true;
    }

    function currentReward(uint256 poolId, address staker)
        public
        view
        returns (uint256)
    {
        uint256 totalRewardAmount = stakes[poolId][staker]
            .amount
            .mul(stakePools[poolId].rewardApply)
            .div(1e12)
            .div(100);
        uint256 totalDuration = stakePools[poolId].endTime.sub(
            stakes[poolId][staker].startingTime
        );
        uint256 duration = (
            block.timestamp > stakePools[poolId].endTime
                ? stakePools[poolId].endTime
                : block.timestamp
        ).sub(stakes[poolId][staker].startingTime);
        uint256 rewardAmount = totalRewardAmount.mul(duration).div(
            totalDuration
        );
        return rewardAmount.sub(stakes[poolId][staker].rewardOut);
    }

    function rand() internal view returns (uint256) {
        return randMod(2**16);
    }

    function randMod(uint256 _modulus) internal view returns (uint256) {
        return
            uint256(
                keccak256(
                    abi.encodePacked(block.timestamp, msg.sender, randNonce)
                )
            ) % _modulus;
    }
}
