// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.4;

contract BlindAuction {
    struct Bid {
        bytes32 blindedBid;
        uint deposit;
    }

    address payable public beneficiary;
    uint public biddingEnd;
    uint public revealEnd;
    bool public ended;

    mapping(address => Bid[]) public bids;

    address public highestBidder;
    uint public highestBid;

    // Allowed withdrawals of previous bids
    mapping (address => uint) pendingReturns;

    event BlindAuction__AuctionEnded(address winner, uint highestBid);

    error BlindAuction__TooEarly(uint time);
    error BlindAuction__TooLate(uint time);
    error BlindAuction__AuctionEndAlreadyCalled();

    modifier onlyBefore(uint time) {
        if(block.timestamp >= time) revert BlindAuction__TooLate(time);
        _;
    }

    modifier onlyAfter(uint time) {
        if(block.timestamp <= time) revert BlindAuction__TooEarly(time);
        _;
    }

    constructor(uint biddingTime, uint revealTime, address payable beneficiaryAddress) {
        beneficiary = beneficiaryAddress;
        biddingEnd = block.timestamp + biddingTime;
        revealEnd = biddingEnd + revealTime;
    }

    function bid(bytes32 blindedBid) external payable onlyBefore(biddingEnd) {
        bids[msg.sender].push(Bid({
            blindedBid: blindedBid,
            deposit: msg.value
        }));
    }

    /// Reveal your blinded bids. You will get a refund for all
    /// correctly blinded invalid bids and for all bids except for
    /// the totally highest.
    function reveal(uint[] calldata values, bool[] calldata fakes, bytes32[] calldata secrets) external onlyAfter(biddingEnd) onlyBefore(revealEnd) {
        uint length = bids[msg.sender].length;
        require(values.length == length);
        require(fakes.length == length);
        require(secrets.length == length);

        uint refund;
        for(uint i = 0; i < length; i++) {
            Bid storage bidToCheck = bids[msg.sender][i];
            (uint value, bool fake, bytes32 secret) = (values[i], fakes[i], secrets[i]);

            if(bidToCheck.blindedBid != keccak256(abi.encodePacked(value, fake, secret))) continue;

            refund += bidToCheck.deposit;

            if(!fake && bidToCheck.deposit >= value) {
                if(placeBid(msg.sender, value))
                    refund -= value;
            }
            
            // Make it impossible for the sender to re-claim
            // the same deposit.
            bidToCheck.blindedBid = bytes32(0);
        }

        payable(msg.sender).transfer(refund);
    }

    function withdraw() external {
        uint amount = pendingReturns[msg.sender];
        if(amount > 0) {
            // It is important to set this to zero because the recipient
            // can call this function again as part of the receiving call
            // before `transfer` returns
            pendingReturns[msg.sender] = 0;
            payable(msg.sender).transfer(amount);
        }
    }

    /// End the auction and send the highest bid
    /// to the beneficiary.
    function auctionEnd() external onlyAfter(revealEnd) {
        if(ended) revert BlindAuction__AuctionEndAlreadyCalled();

        emit BlindAuction__AuctionEnded(highestBidder, highestBid);

        ended = true;

        beneficiary.transfer(highestBid);
    }

    function placeBid(address bidder, uint value) internal returns (bool success) {
        if(value <= highestBid) return false;

        if(highestBidder != address(0)) pendingReturns[highestBidder] += highestBid;

        highestBid = value;
        highestBidder = bidder;

        return true;
    }
}