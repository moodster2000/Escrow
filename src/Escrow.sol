// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Address.sol";

/**
 * @title Escrow
 * @dev A contract that allows users to deposit ERC20 tokens into an escrow
 * and withdraw them after a lock period of 3 days.
 */
contract Escrow is ReentrancyGuard {
    using SafeERC20 for IERC20;

    struct Deposit {
        address token;
        uint256 amount;
        uint256 releaseTime;
        bool withdrawn;
    }

    mapping(address => Deposit) private deposits;

    /**
     * @dev Emitted when tokens are deposited into the escrow.
     * @param user The address of the user who made the deposit.
     * @param token The address of the ERC20 token deposited.
     * @param amount The amount of tokens deposited.
     * @param releaseTime The time after which the tokens can be withdrawn.
     */
    event Deposited(address indexed user, address indexed token, uint256 amount, uint256 releaseTime);

    /**
     * @dev Emitted when tokens are withdrawn from the escrow.
     * @param user The address of the user who withdrew the tokens.
     * @param token The address of the ERC20 token withdrawn.
     * @param amount The amount of tokens withdrawn.
     */
    event Withdrawn(address indexed user, address indexed token, uint256 amount);

    /**
     * @notice Deposit ERC20 tokens into the escrow contract.
     * @param token The address of the ERC20 token to deposit.
     * @param amount The amount of tokens to deposit.
     * @dev The caller must approve the contract to transfer the specified amount of tokens.
     * The tokens will be locked for 3 days.
     */
    function deposit(address token, uint256 amount) external nonReentrant {
        require(amount > 0, "Amount must be greater than 0");
        require(deposits[msg.sender].amount == 0, "Existing deposit found");

        // Transfer tokens to the contract using SafeERC20
        uint256 balanceBefore = IERC20(token).balanceOf(address(this));
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        uint256 balanceAfter = IERC20(token).balanceOf(address(this));
        uint256 actualAmount = balanceAfter - balanceBefore;

        // Record the deposit details
        deposits[msg.sender] = Deposit({
            token: token,
            amount: actualAmount,
            releaseTime: block.timestamp + 3 days,
            withdrawn: false
        });

        emit Deposited(msg.sender, token, actualAmount, block.timestamp + 3 days);
    }

    /**
     * @notice Withdraw deposited tokens after the lock period.
     * @dev The caller must have a valid deposit, and the tokens must be unlocked.
     */
    function withdraw() external nonReentrant {
        Deposit storage currentDeposit = deposits[msg.sender];
        require(currentDeposit.amount > 0, "No deposit found");
        require(block.timestamp >= currentDeposit.releaseTime, "Tokens are still locked");
        require(!currentDeposit.withdrawn, "Tokens already withdrawn");

        currentDeposit.withdrawn = true;

        // Transfer tokens to the user using SafeERC20
        IERC20(currentDeposit.token).safeTransfer(msg.sender, currentDeposit.amount);

        emit Withdrawn(msg.sender, currentDeposit.token, currentDeposit.amount);
    }

    /**
     * @notice Get the details of a user's deposit.
     * @param buyer The address of the user to query.
     * @return token The address of the ERC20 token deposited.
     * @return amount The amount of tokens deposited.
     * @return releaseTime The timestamp when the tokens can be withdrawn.
     * @return withdrawn Whether the tokens have been withdrawn.
     */
    function getDeposit(address buyer) external view returns (address token, uint256 amount, uint256 releaseTime, bool withdrawn) {
        Deposit storage currentDeposit = deposits[buyer];
        return (currentDeposit.token, currentDeposit.amount, currentDeposit.releaseTime, currentDeposit.withdrawn);
    }
}
