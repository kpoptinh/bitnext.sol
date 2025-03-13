// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract BitexpStaking {
    struct Stake {
        uint256 amount;
        uint256 timestamp;
        uint256 duration;
        uint256 apy;
        bool isActive;
    }
    
    struct Referral {
        address referrer;
        uint256 totalEarnings;
    }
    
    mapping(address => Stake[]) public stakes;
    mapping(address => Referral) public referrals;
    mapping(address => address[]) public referredUsers;
    
    uint256 public constant MINIMUM_STAKE = 100 * 10**18; // 100 USD
    uint256 public constant PREMIUM_THRESHOLD = 5000 * 10**18; // 5000 USD
    uint256 public constant REFERRAL_BONUS = 15; // 15%
    
    event Staked(address indexed user, uint256 amount, uint256 duration);
    event Unstaked(address indexed user, uint256 amount, uint256 reward);
    event ReferralBonus(address indexed referrer, address indexed referred, uint256 amount);

    function getAPY(uint256 amount, uint256 duration) public pure returns (uint256) {
        if (amount >= PREMIUM_THRESHOLD) {
            if (duration == 7 days) return 60; // 0.6%
            if (duration == 30 days) return 80; // 0.8%
            if (duration == 90 days) return 90; // 0.9%
            if (duration == 180 days) return 100; // 1.0%
            if (duration == 360 days) return 130; // 1.3%
        } else {
            if (duration == 7 days) return 20; // 0.2%
            if (duration == 30 days) return 40; // 0.4%
            if (duration == 90 days) return 60; // 0.6%
            if (duration == 180 days) return 80; // 0.8%
            if (duration == 360 days) return 90; // 0.9%
        }
        revert("Invalid duration");
    }
    
    function stake(uint256 duration, address referrer) external payable {
        require(msg.value >= MINIMUM_STAKE, "Minimum stake not met");
        require(
            duration == 7 days || 
            duration == 30 days || 
            duration == 90 days || 
            duration == 180 days || 
            duration == 360 days, 
            "Invalid duration"
        );
        
        uint256 apy = getAPY(msg.value, duration);
        
        stakes[msg.sender].push(Stake({
            amount: msg.value,
            timestamp: block.timestamp,
            duration: duration,
            apy: apy,
            isActive: true
        }));
        
        if (referrer != address(0) && referrals[msg.sender].referrer == address(0)) {
            referrals[msg.sender].referrer = referrer;
            referredUsers[referrer].push(msg.sender);
        }
        
        emit Staked(msg.sender, msg.value, duration);
    }
    
    function calculateReward(address user, uint256 stakeIndex) public view returns (uint256) {
        Stake memory userStake = stakes[user][stakeIndex];
        if (!userStake.isActive) return 0;
        
        uint256 timeElapsed = block.timestamp - userStake.timestamp;
        if (timeElapsed < userStake.duration) return 0;
        
        uint256 dailyReturn = (userStake.amount * userStake.apy) / 10000;
        return dailyReturn * (timeElapsed / 1 days);
    }
    
    function calculateReferralBonus(uint256 amount) public pure returns (uint256) {
        return (amount * REFERRAL_BONUS) / 100;
    }
    
    function unstake(uint256 stakeIndex) external {
        require(stakeIndex < stakes[msg.sender].length, "Invalid stake index");
        Stake storage userStake = stakes[msg.sender][stakeIndex];
        require(userStake.isActive, "Stake not active");
        require(block.timestamp >= userStake.timestamp + userStake.duration, "Staking period not completed");
        
        uint256 reward = calculateReward(msg.sender, stakeIndex);
        uint256 referralBonus = 0;
        
        if (referrals[msg.sender].referrer != address(0)) {
            referralBonus = calculateReferralBonus(reward);
            payable(referrals[msg.sender].referrer).transfer(referralBonus);
            referrals[msg.sender].totalEarnings += referralBonus;
            emit ReferralBonus(referrals[msg.sender].referrer, msg.sender, referralBonus);
        }
        
        userStake.isActive = false;
        uint256 totalAmount = userStake.amount + reward;
        payable(msg.sender).transfer(totalAmount);
        
        emit Unstaked(msg.sender, userStake.amount, reward);
    }
}