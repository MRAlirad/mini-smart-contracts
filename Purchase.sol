// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.4;

contract Purchase {
    uint public value;
    address payable public seller;
    address payable public buyer;

    enum State {Created, Locked, Release, Inactive}

    State public state;

    error Purchase__OnlyBuyer();
    error Purchase__OnlySeller();
    error Purchase__InvalidState();
    error Purchase__ValueNotEven();

    modifier condition(bool condition_) {
        require(condition_);
        _;
    }

    modifier onlyBuyer() {
        if (msg.sender != buyer) revert Purchase__OnlyBuyer();
        _;
    }

    modifier onlySeller() {
        if (msg.sender != seller) revert Purchase__OnlySeller();
        _;
    }

    modifier inState(State state_) {
        if (state != state_) revert Purchase__InvalidState();
        _;
    }

    event Aborted();
    event PurchaseConfirmed();
    event ItemReceived();
    event SellerRefunded();

    // Ensure that `msg.value` is an even number.
    // Division will truncate if it is an odd number.
    // Check via multiplication that it wasn't an odd number.
    constructor() payable {
        seller = payable(msg.sender);
        value = msg.value/2;
        if((2 * value) != msg.value) revert Purchase__ValueNotEven();
    }

    /// Abort the purchase and reclaim the ether.
    /// Can only be called by the seller before
    /// the contract is locked.
    function abort() external onlySeller inState(State.Created){
        emit Aborted();
        state = State.Inactive;
        seller.transfer(address(this).balance);
    }

    /// Confirm the purchase as buyer.
    /// Transaction has to include `2 * value` ether.
    /// The ether will be locked until confirmReceived
    /// is called.
    function confirmPurchase() external inState(State.Created) condition(msg.value == (2* value)) payable {
        emit PurchaseConfirmed();
        buyer = payable(msg.sender);
        state = State.Locked;
    }

    /// Confirm that you (the buyer) received the item.
    /// This will release the locked ether.
    function ConfirmedReceived() external onlyBuyer inState(State.Locked) {
        emit ItemReceived();

        // It is important to change the state first because
        // otherwise, the contracts called using `send` below
        // can call in again here.
        state = State.Release;

        buyer.transfer(value);
    }

    function refundSeller() external onlySeller inState(State.Release) {
        emit SellerRefunded();

        // It is important to change the state first because
        // otherwise, the contracts called using `send` below
        // can call in again here.
        state = State.Inactive;

        seller.transfer(3 * value);
    }
}