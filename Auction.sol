// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

contract Auction {
    address payable public beneficiary;
    uint public auctionEndTime;

    // Current state of the auction.
    address public highestBidder;
    uint public highestBid;

    mapping(address => uint) pendingReturns;

    // Set to true at the end, disallows any change.
    // By default initialized to `false`.
    bool ended;

    event HighestBidIncreased(address bidder, uint amount);
    event AuctionEnded(address winner, uint amount);

    error Auction__AuctionAlreadyEnded();
    error Auction__BidNotHighEnough();
    error Auction__AuctionNotYetEnded();
    error Auction__AuctionEndAlreadyCalled();

    constructor(uint biddingTime, address payable beneficiaryAddress) {
        beneficiary = beneficiaryAddress;
        auctionEndTime = block.timestamp + biddingTime;
    }

    /// Bid on the auction with the value sent
    /// together with this transaction.
    function bid() external payable {
        if(block.timestamp > auctionEndTime) revert Auction__AuctionAlreadyEnded();

        if(msg.value <= highestBid) revert Auction__BidNotHighEnough();

        if(highestBid != 0) {
            // let the recipients withdraw their Ether themselves.
            pendingReturns[highestBidder] += highestBid;
        }

        highestBidder = msg.sender;
        highestBid = msg.value;

        emit HighestBidIncreased(msg.sender, msg.value);
    }

    /// Allows outbid bidders to withdraw their Ether from pendingReturns.  
    function withdraw() external returns (bool) {
        uint amount = pendingReturns[msg.sender];

        if(amount > 0) {
            pendingReturns[msg.sender] = 0;

            if(!payable(msg.sender).send(amount)) {
                pendingReturns[msg.sender] = amount;
                return false;
            }
        }
        return true;
    }

    /// End the auction 
    /// send the highest bid to the beneficiary.
    function auctionEnd() external {
        if(block.timestamp < auctionEndTime) revert Auction__AuctionNotYetEnded();

        if(ended) revert Auction__AuctionEndAlreadyCalled();

        ended = true;
        emit AuctionEnded(highestBidder, highestBid);

        beneficiary.transfer(highestBid);
    }

}