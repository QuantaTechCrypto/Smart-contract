// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;


import "./IERC20.sol";
import "./SafeMath.sol";


contract QUANTA is IERC20 {
    using SafeMath for uint256;

    struct LockedTokens {
        uint256 amount;
        uint256 releaseTime;
    }

    struct LinearLockedTokens {
        uint256 amount;
        uint256 lockMonthCount;
        uint256 unlockMonthCount;
    }

    struct PresaleLockedTime {
        uint256 monthCountAfterStart;
        uint256 lockMonthCount;
        uint256 unlockMonthCount;
    }

    mapping(address => uint256) private _balances;
    mapping(address => uint256) private _firstInvestors;
    mapping(address => bool) private _lockedPresaleAddress;
    mapping(address => LockedTokens[]) private _lockedUntil;
    mapping(address => LinearLockedTokens[]) private _linearLockedUntil;
    mapping(address => mapping(address => uint256)) private _allowances;

    address private _owner;
    address private _lockedAddress;
    string private _name;
    string private _symbol;
    uint8 private _decimals;
    uint256 private _startTime;
    uint256 private _maxSupply;
    uint256 private _totalSupply;
    uint256 private _initialSupply;
    uint256 private _month = 30.5 * 1 days;
    uint256[] private _maxMint;
    PresaleLockedTime private _presaleLockedTime;

    constructor() {        
        _owner = msg.sender;
        _name = "Quanta Technology";
        _symbol = "QUANTA";
        _decimals = 12;
        _startTime = block.timestamp;
        _lockedAddress = 0x318e6BCFDDf1f256F8bd88113852B834d019cFb4;
        _maxSupply = 800_000_000 * (10 ** _decimals);
        _initialSupply = 50_000_000 * (10 ** _decimals);

        _presaleLockedTime.monthCountAfterStart = 3 * _month;
        _presaleLockedTime.lockMonthCount = 14 * _month;
        _presaleLockedTime.unlockMonthCount = 14;

        _maxMint = [5_000_000_000, 0, 0, 1_000_000_000, 800_000_000, 800_000_000, 800_000_000, 800_000_000, 800_000_000, 800_000_000, 3_600_000_000, 800_000_000,
                    4_000_000_000, 1_600_000_000, 1_600_000_000, 18_200_000_000, 1_600_000_000, 1_600_000_000, 1_600_000_000, 4_800_000_000, 4_800_000_000, 
                    5_022_222_226, 5_022_222_226, 3_622_222_222, 1_022_222_222, 1_022_222_222, 1_022_222_222, 1_022_222_222, 1_022_222_222, 222_222_222, 222_222_222, 
                    222_222_222, 222_222_222, 222_222_222, 222_222_222, 222_222_222, 222_222_222, 222_222_222, 222_222_222, 222_222_222, 222_222_222, 222_222_222, 
                    222_222_222, 222_222_222, 222_222_222, 222_222_222, 222_222_222, 222_222_222, 222_222_222, 222_222_222, 222_222_222, 222_222_222, 222_222_222,
                    222_222_222, 222_222_222, 222_222_222, 222_222_222];

        for (uint256 i = 0; i < _maxMint.length; i++) {
            _maxMint[i] = _maxMint[i] * (10 ** 10);
        }

        _mint(_owner, _initialSupply);
    }

    modifier onlyOwner() {
        require(msg.sender == _owner, "Only owner");
        _;
    }

    function maxMint() public view virtual returns (uint256) {
        uint256 availabMintAmount = 0;

        if ((block.timestamp - _startTime) / _month < _maxMint.length) {
            for (uint256 i = 0; i < ((block.timestamp - _startTime) / _month) + 1; i++) {
                availabMintAmount += _maxMint[i];
            }
            return availabMintAmount - totalSupply();
        }

        return maxSupply() - totalSupply();
    }

    function name() public view virtual returns (string memory) {
        return _name;
    }

    function symbol() public view virtual returns (string memory) {
        return _symbol;
    }

    function decimals() public view virtual returns (uint8) {
        return _decimals;
    }

    function totalSupply() public view virtual override returns (uint256) {
        return _totalSupply;
    }

    function maxSupply() public view virtual returns (uint256) {
        return _maxSupply;
    }

    function initialSupply() public view virtual returns (uint256) {
        return _initialSupply;
    }

    function lockedAddress() public view virtual returns (address) {
        return _lockedAddress;
    }

    function addPresaleAdress(address presaleAddress) public onlyOwner virtual returns (bool) {
        _lockedPresaleAddress[presaleAddress] = true;
        return true;
    }

    function delPresaleAdress(address presaleAddress) public onlyOwner virtual returns (bool) {
        _lockedPresaleAddress[presaleAddress] = false;
        return true;
    }

    function getPresaleAdress(address presaleAddress) public view virtual returns (bool) {
        return _lockedPresaleAddress[presaleAddress];
    }

    function addFirstInvestor(address recipient, uint256 amount) public onlyOwner virtual returns (bool) {
        _firstInvestors[recipient] = _firstInvestors[recipient].add(amount);
        return true;
    }

    function getFirstInvestor(address recipient) public view virtual returns (uint256) {
        return _firstInvestors[recipient];
    }

    function availableBalance(address recipient) public view virtual returns (uint256) {
        uint256 lockedBalance = 0;

        for (uint256 i = 0; i < _lockedUntil[recipient].length; i++) {
            if (_lockedUntil[recipient][i].releaseTime > block.timestamp) {
                lockedBalance += _lockedUntil[recipient][i].amount;
            }
        }

        for (uint256 i = 0; i < _linearLockedUntil[recipient].length; i++) {
            uint256 amountStep = _linearLockedUntil[recipient][i].amount / _linearLockedUntil[recipient][i].unlockMonthCount;

            for (uint256 x = 0; x < _linearLockedUntil[recipient][i].unlockMonthCount; x++) {
                if (_linearLockedUntil[recipient][i].lockMonthCount + (x * _month) >= block.timestamp) {
                    lockedBalance += amountStep;
                }
            }
        }

        return balanceOf(recipient) - lockedBalance;
    }

    function setPresaleLockedTime(uint256 monthCountAfterStart, uint256 lockMonthCount, uint256 unlockMonthCount) public onlyOwner returns (bool) {
        require(monthCountAfterStart != 0 , "Month count after start must be greater than 0");
        require(lockMonthCount != 0 , "Lock month count must be greater than 0");
        require(unlockMonthCount != 0 , "unlock month count must be greater than 0");

        _presaleLockedTime.monthCountAfterStart = monthCountAfterStart * _month;
        _presaleLockedTime.lockMonthCount = lockMonthCount * _month;
        _presaleLockedTime.unlockMonthCount = unlockMonthCount;

        return true;
    }

    function transferWithLinearLock(address recipient, uint256 amount, uint256 lockMonthCount, uint unlockMonthCount) public onlyOwner returns (bool) {
        require(lockMonthCount != 0 , "Lock month count must be greater than 0");
        require(unlockMonthCount != 0 , "Unlock month count must be greater than 0");
        _transfer(msg.sender, recipient, amount);

        LinearLockedTokens memory newLockedTokens = LinearLockedTokens(amount, block.timestamp + (lockMonthCount * _month), unlockMonthCount);
        _linearLockedUntil[recipient].push(newLockedTokens);
        return true;
    }

    function transferWithLock(address recipient, uint256 amount, uint256 daysToLock) public onlyOwner returns (bool) {
        require(daysToLock != 0 , "Days count must be greater than 0");
        _transfer(msg.sender, recipient, amount);

        LockedTokens memory newLockedTokens = LockedTokens(amount, block.timestamp + (daysToLock * 1 days));
        _lockedUntil[recipient].push(newLockedTokens);
        return true;
    }

    function balanceOf(address account) public view virtual override returns (uint256) {
        return _balances[account];
    }

    function transfer(address recipient, uint256 amount) public virtual override returns (bool) {
        _transfer(msg.sender, recipient, amount);
        return true;
    }

    function allowance(address owner, address spender) public view virtual override returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) public virtual override returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) public virtual override returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(sender, msg.sender, _allowances[sender][msg.sender].sub(amount));
        return true;
    }

    function mint(uint256 amount) public onlyOwner virtual returns (bool) {
        require(amount <= maxMint(), "Exceeds available maximum");
        require(_totalSupply + amount <= _maxSupply, "Max supply reached");

        _mint(msg.sender, amount);
        return true;
    }

    function burn(uint256 amount) public onlyOwner virtual returns (bool) {
        _burn(msg.sender, amount);
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        _approve(msg.sender, spender, _allowances[msg.sender][spender].add(addedValue));
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        _approve(msg.sender, spender, _allowances[msg.sender][spender].sub(subtractedValue));
        return true;
    }

    function _transfer(address sender, address recipient, uint256 amount) internal virtual {
        require(balanceOf(sender) >= amount, "Insufficient balance");
        require(sender != _lockedAddress, "Sender address is locked");
        require(amount <= availableBalance(sender), "Tokens is locked");
        require(amount > 0, "Transfer amount must be greater than zero");
        require(sender != address(0), "BEP20: transfer from the zero address");
        require(recipient != address(0), "BEP20: transfer to the zero address");

        if (_lockedPresaleAddress[msg.sender]) {
            uint256 time = _startTime + _presaleLockedTime.monthCountAfterStart + _presaleLockedTime.lockMonthCount;
            _linearLockedUntil[recipient].push(LinearLockedTokens(amount, time, _presaleLockedTime.unlockMonthCount));
        } 

        _beforeTokenTransfer(sender, recipient, amount);
        _balances[sender] = _balances[sender].sub(amount);
        _balances[recipient] = _balances[recipient].add(amount);

        if (balanceOf(sender) < _firstInvestors[sender]) {
            _firstInvestors[sender] = _firstInvestors[sender].sub(_firstInvestors[sender].sub(balanceOf(sender)));
        }

        emit Transfer(sender, recipient, amount);
    }

    function _mint(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: mint to the zero address");
        _beforeTokenTransfer(address(0), account, amount);
        _totalSupply = _totalSupply.add(amount);
        _balances[account] = _balances[account].add(amount);
        emit Transfer(address(0), account, amount);
    }

    function _burn(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: burn from the zero address");
        _beforeTokenTransfer(account, address(0), amount);
        _totalSupply = _totalSupply.sub(amount);
        _balances[account] = _balances[account].sub(amount);
        emit Transfer(account, address(0), amount);
    }

    function _approve(address owner, address spender, uint256 amount) internal virtual {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");
        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _setupDecimals(uint8 decimals_) internal virtual {
        _decimals = decimals_;
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual {}
}
