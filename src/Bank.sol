// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;


contract Bank{
    address private owner;
    mapping(address => uint256) public balances;
    uint256 public total;
    address[3] private _top3;

    event Deposit(address indexed user, address indexed from, uint256 amount, uint256 newBalance);
    event Withdraw(address indexed recipient, uint256 amount, uint256 remainingBalance);
    event LeaderboardUpdated(address[3] top3);
    // event for EVM logging
    event OwnerSet(address indexed oldOwner, address indexed newOwner);

    // modifier to check if caller is owner
    modifier isOwner() {
        // If the first argument of 'require' evaluates to 'false', execution terminates and all
        // changes to the state and to Ether balances are reverted.
        // This used to consume all gas in old EVM versions, but not anymore.
        // It is often a good idea to use 'require' to check if functions are called correctly.
        // As a second argument, you can also provide an explanation about what went wrong.
        require(msg.sender == owner, "Caller is not owner");
        _;
    }

    constructor() {
        owner = msg.sender; // 'msg.sender' is sender of current call, contract deployer for a constructor
        emit OwnerSet(address(0), owner);
        _top3 = [address(0), address(0), address(0)];
    }

    /**
     * @dev Deposit on behalf of `_to`. Allows contracts or dapps to fund users.
     */
    function deposit(address _to) external payable  {
        require(_to != address(0), "Invalid recipient");
        _processDeposit(_to, msg.sender, msg.value);
    }

    /**
     * @dev Allow direct transfers (e.g. from MetaMask) to be tracked as deposits.
     */
    receive() external payable {
        _processDeposit(msg.sender, msg.sender, msg.value);
    }

    function withdraw(uint256 _amount) public isOwner {
        require(_amount > 0, "Amount must be greater than 0");
        require(total > 0, "No funds available");

        uint256 withdrawAmount = (_amount > total) ? total : _amount;
        total -= withdrawAmount;

        (bool success, ) = payable(owner).call{value: withdrawAmount}("");
        require(success, "Transfer failed");

        emit Withdraw(owner, withdrawAmount, total);
    }

    // 可以不需要receive函数，因为deposit已经可以转账了，除非想有事没事就给合约转账但不用记在账上（即deposit上）
    // receive() external payable {}
    
    /**
     * @dev Change owner
     * @param newOwner address of new owner
     */
    function changeOwner(address newOwner) public isOwner {
        require(newOwner != address(0), "New owner should not be the zero address");
        emit OwnerSet(owner, newOwner);
        owner = newOwner;
    }

    /**
     * @dev Return owner address 
     * @return address of owner
     */
    function getOwner() external view returns (address) {
        return owner;
    }

    function top3() external view returns (address[3] memory) {
        return _top3;
    }

    function _processDeposit(address user, address from, uint256 amount) internal {
        require(amount > 0, "Amount must be greater than 0");
        balances[user] += amount;
        total += amount;
        _removeFromLeaderboard(user);
        _updateLeaderboard(user, balances[user]);
        emit Deposit(user, from, amount, balances[user]);
        emit LeaderboardUpdated(_top3);
    }

    function _removeFromLeaderboard(address user) internal {
        for (uint256 i = 0; i < 3; i++) {
            if (_top3[i] == user) {
                for (uint256 j = i; j < 2; j++) {
                    _top3[j] = _top3[j + 1];
                }
                _top3[2] = address(0);
                break;
            }
        }
    }

    function _updateLeaderboard(address user, uint256 newBalance) internal {
        if (newBalance > balances[_top3[0]]) {
            _shiftDown(0);
            _top3[0] = user;
        } else if (newBalance > balances[_top3[1]]) {
            _shiftDown(1);
            _top3[1] = user;
        } else if (newBalance > balances[_top3[2]]) {
            _top3[2] = user;
        }
    }

    function _shiftDown(uint256 idx) internal {
        for (uint256 i = 2; i > idx; i--) {
            _top3[i] = _top3[i - 1];
        }
    }

}
