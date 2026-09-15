// SPDX-License-Identifier: MIT
pragma solidity ^0.8.34;

import "https://github.com/openzeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/IERC20.sol";

contract TokenVesting {
    IERC20 public token;

    address public owner;

    constructor(address _initialAddress) {
        token = IERC20(_initialAddress);

        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(owner == msg.sender, "You Are Not Owner");
        _;
    }

    struct VestingSchedule {
        address beneficiary;
        uint256 totalAmount;
        uint256 start;
        uint256 cliff;
        uint256 duration;
        uint256 claimed;
    }

    mapping(uint256 => VestingSchedule) public vestingSchedules;

    mapping(address => uint256[]) public beneficiarySchedules;

    uint256 public nextScheduleId;

    function createVesting(
        address _beneficiary,
        uint256 _totalAmount,
        uint256 _start,
        uint256 _cliff,
        uint256 _duration
    ) public onlyOwner {
        require(_beneficiary != address(0), "Invalid beneficiary");
        require(_totalAmount > 0, "Amount Must Be Greater Than Zero");
        require(_duration > 0, "Duration must be greater than Zero");
        require(_cliff <= _duration, "Cliff exceeds duration");

        uint256 scheduleId = nextScheduleId;

        vestingSchedules[scheduleId] = VestingSchedule({
            beneficiary: _beneficiary,
            totalAmount: _totalAmount,
            start: _start,
            cliff: _cliff,
            duration: _duration,
            claimed: 0
        });

        beneficiarySchedules[_beneficiary].push(scheduleId);

        token.transferFrom(msg.sender, address(this), _totalAmount);

        nextScheduleId++;
    }

    function vestedAmount(uint256 _scheduleId) public view returns (uint256) {
        VestingSchedule memory schedule = vestingSchedules[_scheduleId];

        if (block.timestamp < schedule.start) {
            return 0;
        }

        if (block.timestamp >= schedule.start + schedule.duration) {
            return schedule.totalAmount;
        }

        uint256 elapsedTime = block.timestamp - schedule.start;

        return (schedule.totalAmount * elapsedTime) / schedule.duration;
    }

    function claim(uint256 _scheduleId) public {
        VestingSchedule storage schedule = vestingSchedules[_scheduleId];

        require(
            msg.sender == schedule.beneficiary,
            "Only the beneficiary can claim"
        );

        uint256 cliffTime = schedule.start + schedule.cliff;

        require(block.timestamp >= cliffTime, "Cliff not reached");

        uint256 vested = vestedAmount(_scheduleId);

        uint256 claimable = vested - schedule.claimed;

        require(claimable > 0, "Nothing For Claim");

        schedule.claimed += claimable;

        token.transfer(schedule.beneficiary, claimable);
    }
}
