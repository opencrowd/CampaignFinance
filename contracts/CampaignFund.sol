pragma solidity ^0.4.19;

import './SafeMath.sol';
import './Ownable.sol';
import './ERC223ReceivingContract.sol';
import './ERC223.sol';
import './CampaignRegistry.sol';


contract CampaignFund is Ownable, ERC223ReceivingContract {

    using SafeMath for uint256;

    mapping(address => uint8) private _owners;


    struct Transaction {
      address from;
      address to;
      uint amount;
      uint8 signatureCount;
      mapping (address => uint8) signatures;
    }

    mapping (uint => Transaction) private _transactions;
    uint[] private _pendingTransactions;


    uint private transactionIdx;
    uint constant MIN_SIGNATURES = 3;
    address tokenAddress;
    uint maxDonation;
    CampaignRegistry Registry;

    mapping (address => uint) ContributionTracker;

    event ownerAdded(address newOwner);
    event ownerRemoved(address deletedOwner);

    event Contribution(address contributor, address reciever, uint amount, uint timestamp);

    event transactionCreated(address campagin, address reciever, uint amount, uint timestamp);
    event TransactionCompleted(address from, address to, uint amount, uint transactionId, uint timestamp);
    event TransactionSigned(address by, uint transactionId);

    modifier validOwner() {
        require(msg.sender == owner || _owners[msg.sender] == 1);
        _;
    }


    function CampaignFund( uint _maxDonation ) public {
        Registry= CampaignRegistry(0x5ec375abedb991365bd12a37acfb7476891d9592);
        tokenAddress = 0xc2a6002d467b7caddfafb914aed4ca77f54fab3e;
        Registry.addCampaignID(this,msg.sender);
        maxDonation= _maxDonation;
    }

    function addOwner(address _owner)
      onlyOwner
      public {
        _owners[owner] = 1;
        ownerAdded(_owner);
      }

    function removeOwner(address _owner)
      onlyOwner
      public {
        _owners[owner] = 0;
        ownerRemoved(_owner);
      }


    function contribute(uint _amount) public {
        require (SafeMath.add(ContributionTracker[msg.sender],_amount) <= maxDonation );
        require(Registry.isContributor(msg.sender));
        ContributionTracker[msg.sender]= SafeMath.add(ContributionTracker[msg.sender], _amount);
        require(ERC223(tokenAddress).transferFrom(msg.sender, this, _amount));

    }

    function tokenFallback(address _from, uint _value) public {
        require(Registry.isContributor(_from));
        require(SafeMath.add(ContributionTracker[_from],_value) <= maxDonation);
        Contribution(_from, this, _value, now);
    }


    function getFundBalance() public constant returns(uint256) {
        return (ERC223(tokenAddress).balanceOf(this));
    }

    function pay(address _to, uint256 _amount) onlyOwner public {
      require(Registry.isPayee(_to));
      uint _transactionId = transactionIdx++;
      Transaction memory transaction;
      transaction.from = this;
      transaction.to = _to;
      transaction.amount = _amount;
      transaction.signatureCount = 0;

      _transactions[_transactionId] = transaction;
      _pendingTransactions.push(_transactionId);
      transactionCreated(this, _to, _amount, now);
    }

    function getPendingTransactions()
      view
      public
      returns (uint[]) {
      return _pendingTransactions;
    }


    function signTransaction(uint transactionId)
      validOwner
      public {

      Transaction storage transaction = _transactions[transactionId];

      // Transaction must exist
      require(0x0 != transaction.from);
      // Cannot sign a transaction more than once
      require(transaction.signatures[msg.sender] != 1);

      transaction.signatures[msg.sender] = 1;
      transaction.signatureCount++;

      TransactionSigned(msg.sender, transactionId);

      if (transaction.signatureCount >= MIN_SIGNATURES) {
        ERC223(tokenAddress).transfer(transaction.to, transaction.amount);
        TransactionCompleted(transaction.from, transaction.to, transaction.amount, transactionId,now);
      }
    }



}
