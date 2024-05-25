// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";

contract Hoarder is Ownable, Pausable, ReentrancyGuard {
    constructor() Ownable(msg.sender) {}

    using Address for address;
    using ERC165Checker for address;

    /**
     * Value each NFT will be harvested for (in wei).
     */
    uint256 public constant FIXED_NFT_VALUE = 1e10;

    /**
     * Struct which represent a ERC-721 NFT.
     */
    struct NFT {
        address tokenAddress;
        uint256 tokenId;
    }

    struct Currency {
        address tokenAddress;
        uint256 amount;
    }

    /**
     * Event emitted when ETH is sent to the contract.
     */
    event ValueReceived(address indexed sender, uint256 amount);

    /**
     * Event emitted when non fungible token(s) are harvested by the contract.
     */
    event NFTsHarvested(address indexed sender, NFT[] tokens);

    /**
     * Event emitted wieh fungible token(s) are harvested by the contract */
    event CurrenciesHarvested(address indexed sender, Currency[] tokens);

    /**
     * Function which enables external consumers to sell
     * multiple ERC-721 NFTs to the contract. By calling this function,
     * the contract will transfer the tokens to itself (the contract)
     * and pay the sender a fixed amount of ETH.
     */
    function sellNFT(
        NFT[] calldata tokens
    ) external nonReentrant whenNotPaused {
        // Require 'tokens' to not be empty
        require(tokens.length > 0, "Hoarder: 'tokens' must not be empty");

        address payable sender = payable(msg.sender);
        uint256 calculatedValue = FIXED_NFT_VALUE;

        // Require contract to contain enough ETH balance
        require(
            address(this).balance >= calculatedValue,
            "Hoarder: Insufficient Balance"
        );

        for (uint256 i = 0; i < tokens.length; ++i) {
            address tokenAddress = tokens[i].tokenAddress;
            uint256 tokenId = tokens[i].tokenId;

            // Sanity check NFT implements IERC721 interface
            require(
                tokenAddress.supportsInterface(type(IERC721).interfaceId),
                "Hoarder: Token must implement IERC721 interface"
            );

            IERC721 nft = IERC721(tokenAddress);

            // Sanity check NFT is being sold by its owner
            require(
                nft.ownerOf(tokenId) == sender,
                "Hoarder: NFT must be sold by its owner"
            );

            // Safe Transfer NFT to self (this contract)
            nft.safeTransferFrom(sender, address(this), tokenId);
        }

        // Emit event
        emit NFTsHarvested(sender, tokens);

        // Transfer ETH to sender
        Address.sendValue(sender, calculatedValue);
    }

    /**
     * Function which enables external consumers to sell
     * multiple ERC-20 Tokens to the contract. By calling this function,
     * the contract will transfer the tokens to itself (the contract)
     * and pay the sender a fixed amount of ETH.
     */
    function sellCurrency(
        Currency[] calldata tokens
    ) external payable nonReentrant whenNotPaused {
        // Require 'tokens' to not be empty
        require(tokens.length > 0, "Hoarder: 'tokens' must not be empty");

        address payable sender = payable(msg.sender);
        uint256 calculatedValue = FIXED_NFT_VALUE;

        // Require contract to contain enough ETH balance
        require(
            address(this).balance >= calculatedValue,
            "Hoarder: Insufficient Balance"
        );

        for (uint256 i = 0; i < tokens.length; ++i) {
            address tokenAddress = tokens[i].tokenAddress;
            uint256 amount = tokens[i].amount;

            IERC20 currency = IERC20(tokenAddress);

            uint256 allowance = currency.allowance(msg.sender, address(this));
            require(allowance >= amount, "Insufficient allowance");

            currency.transferFrom(sender, address(this), amount);
        }

        // Emit event
        emit CurrenciesHarvested(sender, tokens);

        // Transfer ETH to sender
        Address.sendValue(sender, calculatedValue);
    }

    /**
     * Pause the contract.
     */
    function pause() external nonReentrant onlyOwner whenNotPaused {
        _pause();
    }

    /**
     * Unpause the contract.
     */
    function unpause() external nonReentrant onlyOwner whenPaused {
        _unpause();
    }

    /**
     * Deposit ETH funds into the contract.
     */
    function deposit() external payable nonReentrant whenNotPaused {
        require(msg.value > 0, "Hoarder: Value must be greater than zero");
        emit ValueReceived(msg.sender, msg.value);
    }

    /**
     * Withdrawal ETH funds to the given recipient address.
     */
    function withdraw(
        address payable recipient,
        uint256 amount
    ) external nonReentrant onlyOwner {
        require(amount > 0, "Hoarder: 'amount' must be greater than zero");
        require(
            recipient != address(this),
            "Hoarder: 'recipient' must be an outside account"
        );

        Address.sendValue(recipient, amount);
    }
}
