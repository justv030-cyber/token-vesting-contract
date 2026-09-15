// SPDX-License-Identifier: MIT
pragma solidity ^0.8.34;

// import "https://github.com/openzeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/IERC20.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/utils/SafeERC20.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/ReentrancyGuard.sol";

contract TokenVesting is ReentrancyGuard {
    IERC20 public token;
    using SafeERC20 for IERC20;

    address public owner;

    constructor(address _initialAddress) {
        require(_initialAddress != address(0), "Invalid Address");
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
        bool revoked;
    }

    mapping(uint256 => VestingSchedule) public vestingSchedules;

    mapping(address => uint256[]) public beneficiarySchedules;

    uint256 public nextScheduleId;

    //events

    event VestingCreated(
        uint256 indexed scheduleId,
        address indexed beneficiary,
        uint256 totalAmount,
        uint256 start,
        uint256 cliff,
        uint256 duration
    );

    event TokensClaimed(
        uint256 indexed scheduleId,
        address indexed beneficiary,
        uint256 amount
    );

    event VestingRevoked(
        uint256 indexed scheduleId,
        address indexed beneficiary,
        uint256 beneficiaryAmount,
        uint256 ownerAmount
    );

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
            claimed: 0,
            revoked: false
        });

        beneficiarySchedules[_beneficiary].push(scheduleId);

        token.safeTransferFrom(msg.sender, address(this), _totalAmount);

        nextScheduleId++;

        emit VestingCreated(
            scheduleId,
            _beneficiary,
            _totalAmount,
            _start,
            _cliff,
            _duration
        );
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

    function claim(uint256 _scheduleId) public nonReentrant {
        VestingSchedule storage schedule = vestingSchedules[_scheduleId];

        require(!schedule.revoked, "Vesting Revoked");

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

        token.safeTransfer(schedule.beneficiary, claimable);

        emit TokensClaimed(_scheduleId, schedule.beneficiary, claimable);
    }

    function getClaimableAmount(
        uint256 _scheduleId
    ) public view returns (uint256) {
        VestingSchedule memory schedule = vestingSchedules[_scheduleId];

        if (schedule.revoked) {
            return 0;
        }

        uint256 cliffTime = schedule.start + schedule.cliff;

        if (block.timestamp < cliffTime) {
            return 0;
        }

        uint256 vested = vestedAmount(_scheduleId);

        uint256 claimable = vested - schedule.claimed;

        return claimable;
    }

    function revoke(uint256 _scheduleId) public onlyOwner nonReentrant {
        VestingSchedule storage schedule = vestingSchedules[_scheduleId];

        require(_scheduleId < nextScheduleId, "Invalid Schedule");

        require(!schedule.revoked, "Already Revoked");

        uint256 vested = vestedAmount(_scheduleId);

        uint256 beneficiaryAmount = vested - schedule.claimed;

        uint256 ownerAmount = schedule.totalAmount - vested;

        schedule.revoked = true;

        token.safeTransfer(schedule.beneficiary, beneficiaryAmount);
        token.safeTransfer(owner, ownerAmount);

        emit VestingRevoked(
            _scheduleId,
            schedule.beneficiary,
            beneficiaryAmount,
            ownerAmount
        );
    }
}
