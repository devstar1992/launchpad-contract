//SPDX-License-Identifier: MIT
pragma solidity 0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import "./IPool.sol";
import "./Validations.sol";
import "./Whitelist.sol";
import "./IPancakeRouter02.sol";
contract Pool is IPool, Whitelist {
  using SafeMath for uint256;
  using SafeMath for uint16;
  using SafeMath for uint8;
  IERC20Metadata private projectToken;
  PoolModel public poolInformation;
  PoolDetails public poolDetails;
  address private poolOwner;
  address private admin;
  address private factory;
  address[] public participantsAddress;
  mapping(address => uint256) public collaborations;
  uint256 public _weiRaised = 0;
  mapping(address => bool) public _didRefund;
  uint256 private dexETHAmount;
  uint256 private dexTokenAmount;
  uint8 public  poolPercentFee;
  
  constructor() {
      factory = msg.sender;
  }


  function setPoolModel(PoolModel calldata _pool, IPool.PoolDetails calldata _details, address _admin, address _poolOwner, uint8 _poolPercentFee)
    external
    override
    _onlyFactory 
  {
    _preValidatePoolCreation(_pool, _poolOwner, _poolPercentFee);
    poolInformation = _pool;
    _preValidatePoolDetails(_details);
    poolDetails=_details;
    poolOwner=_poolOwner;
    admin=_admin;
    poolPercentFee=_poolPercentFee;
  }


  modifier _onlyFactory() {
    require(
      address(factory) == msg.sender,
      "Not factory!"
    );
    _;
  }
  modifier _poolIsOngoing(PoolModel storage _pool, PoolDetails storage _poolDetails) {
    require(_pool.status == PoolStatus.Inprogress, "not open!");
    // solhint-disable-next-line not-rely-on-time
    require(_poolDetails.startDateTime <= block.timestamp, "not started");
    // solhint-disable-next-line not-rely-on-time
    require(_poolDetails.endDateTime >= block.timestamp, "end!");

    _;
  }

  modifier _poolIsReadyEnd(PoolModel storage _pool, PoolDetails storage _poolDetails) {
    require(
      _poolDetails.endDateTime <= block.timestamp && _pool.status!= IPool.PoolStatus.Ended && _pool.status!= IPool.PoolStatus.Cancelled,
      "not Ended!"
    );
    _;
  }

  modifier _poolIsReadyLiquidity(PoolModel storage _pool, PoolDetails storage _poolDetails) {
    require(
      _poolDetails.endDateTime+_poolDetails.dexLockup*1 days<= block.timestamp && _pool.status== IPool.PoolStatus.Ended,
      "lockup!"
    );
    _;
  }

  modifier _hardCapNotPassed(uint256 _hardCap) {
    uint256 _beforeBalance = _weiRaised;

    uint256 sum = _weiRaised + msg.value;
    require(sum < _hardCap, "hardCap!");
    require(sum > _beforeBalance, "hardCap overflow!");
    _;
  }

  modifier _minAllocationNotPassed(uint256 _minAllocationPerUser) {
    require(_minAllocationPerUser < msg.value, "Less!");
    _;
  }

  modifier _maxAllocationNotPassed(uint256 _maxAllocationPerUser) {
    collaborations[msg.sender] += msg.value;

    require(collaborations[msg.sender] < _maxAllocationPerUser, "More!");
    _;
  }

  modifier _onlyWhitelisted(address sender) {
    require(!poolDetails.whitelistable || isWhitelisted(sender), "Not!");
    _;
  }

  function updateExtraData(bytes32 _extraData)
    external
    override    
    _onlyFactory
  {
    poolDetails.extraData = _extraData;  
    emit LogPoolExtraData(_extraData);
  }

  function updateKYCStatus(bool _kyc)
    external
    override    
    _onlyFactory
  {
    poolInformation.kyc = _kyc;    
    emit LogPoolKYCUpdate(_kyc);
  }


  function addAddressesToWhitelist(address[] calldata whitelistedAddresses)
    external
    override
    _onlyFactory
  {
    addToWhitelist(whitelistedAddresses);
  }

  function deposit(address sender)
    external
    payable
    override
    _onlyFactory
    _onlyWhitelisted(sender)
    _poolIsOngoing(poolInformation, poolDetails)
    _minAllocationNotPassed(poolDetails.minAllocationPerUser)
    _maxAllocationNotPassed(poolDetails.maxAllocationPerUser)
    _hardCapNotPassed(poolInformation.hardCap)
  {
    uint256 _amount = msg.value;

    _increaseRaisedWEI(_amount);
    _addToParticipants(msg.sender);
    emit LogDeposit(msg.sender, _amount);
  }

  function cancelPool()
    external
    override
    _onlyFactory
  {
    for(uint i=0;i<participantsAddress.length;i++){
      uint refund=collaborations[address(participantsAddress[i])];
      collaborations[address(participantsAddress[i])]=0;
      address addr = participantsAddress[i];
      payable(addr).transfer(refund);      
    }
    poolInformation.status=PoolStatus.Cancelled;
    emit LogPoolStatusChanged(uint(PoolStatus.Cancelled));
  }

  function endPool()
    external
    override
    _onlyFactory
    _poolIsReadyEnd(poolInformation, poolDetails)    
  {
    projectToken = IERC20Metadata(poolInformation.projectTokenAddress);
    //distribute the token
    for(uint i=0;i<participantsAddress.length;i++){
      address _receiver = address(participantsAddress[i]);
      if(_didRefund[_receiver]== false){
        _didRefund[_receiver] = true;
        uint256 _amount = collaborations[_receiver].mul(poolInformation.presaleRate);    
        _amount=_amount.div(10**18);
        projectToken.transfer(_receiver, _amount);
      }
    }
    //pay for the project owner
    uint256 toAdminETHAmount=_weiRaised.mul(poolPercentFee).div(100);
    payable(admin).transfer(toAdminETHAmount);      
    uint256 rest=_weiRaised.sub(toAdminETHAmount);
    // send ETH and Token back to the pool owner
    dexETHAmount=poolInformation.hardCap.mul(poolInformation.dexCapPercent).div(100);
    if(dexETHAmount>=rest){
      dexETHAmount=rest;      
    }else{     
      payable(poolOwner).transfer(rest.sub(dexETHAmount));
    }
    dexTokenAmount=dexETHAmount.mul(poolInformation.dexRate).div(10**18); 
    //refund to the pool owner
    uint256 tokenRest=projectToken.balanceOf(address(this)).sub(dexTokenAmount);
    if(poolDetails.refund==true)
      projectToken.transfer(address(poolOwner), tokenRest);
    else
      projectToken.transfer(address(0), tokenRest);
    poolInformation.status=PoolStatus.Ended;
    emit LogPoolStatusChanged(uint(PoolStatus.Ended));
  }

  function addLiquidityDex()
    external
    override
    _onlyFactory
    _poolIsReadyLiquidity(poolInformation, poolDetails)   
  {
    IPancakeRouter02 pancakeRouter = IPancakeRouter02(address(0x10ED43C718714eb63d5aA57B78B54704E256024E));
    // add the liquidity
    pancakeRouter.addLiquidityETH{value: dexETHAmount}(
        poolInformation.projectTokenAddress,
        dexTokenAmount,
        0, // slippage is unavoidable
        0, // slippage is unavoidable
        poolOwner,
        block.timestamp + 360
    );
  }

  function _preValidatePoolCreation(PoolModel memory _pool, address _poolOwner, uint8 _poolPercentFee) private pure {
    require(_pool.hardCap > 0, "hardCap > 0");
    require(_pool.softCap > 0, "softCap > 0");
    require(_pool.softCap < _pool.hardCap, "softCap < hardCap");
    require(
      address(_poolOwner) != address(0),
      "Owner is a zero address!"
    );
    require(_pool.dexCapPercent > 50 && _pool.dexCapPercent < 100, "dexCapPercent is 51~99%");
    require(_pool.dexRate > 0, "dexRate > 0!");
    require(_pool.presaleRate > _pool.dexRate, "presaleRate > dexRate!");
    require(_poolPercentFee > 0 && _poolPercentFee<100, "percentFee!");
  }

  function _preValidatePoolDetails(PoolDetails memory _poolDetails) private view {  
    require(
      //solhint-disable-next-line not-rely-on-time
      _poolDetails.startDateTime > block.timestamp,"startDate fail!"
    );
    require(
      //solhint-disable-next-line not-rely-on-time
      _poolDetails.endDateTime > block.timestamp,"endDate fail!"
    ); //TODO how much in the future?
    require(
      //solhint-disable-next-line not-rely-on-time
      _poolDetails.startDateTime < _poolDetails.endDateTime,"start<end!"
    );
    require(_poolDetails.minAllocationPerUser > 0);
    require(
      _poolDetails.minAllocationPerUser < _poolDetails.maxAllocationPerUser,"min<max"
    );
  
  }

  function _increaseRaisedWEI(uint256 _amount) private {
    require(_amount > 0, "No WEI found!");

    _weiRaised =_weiRaised.add(msg.value);

    if(_weiRaised==poolInformation.hardCap){
      poolInformation.status=PoolStatus.Finished;
      emit LogPoolStatusChanged(uint(PoolStatus.Finished));
    }
  }

  function _addToParticipants(address _address) private {
    if (!_didAlreadyParticipated(_address)) _addToListOfParticipants(_address);
    _keepRecordOfWEIRaised(_address);
  }

  function _didAlreadyParticipated(address _address)
    private
    view
    returns (bool isIt)
  {
    isIt = collaborations[_address] > 0;
  }

  function _addToListOfParticipants(address _address) private {
    participantsAddress.push(_address);
  }

  function _keepRecordOfWEIRaised(address _address) private {
    collaborations[_address] += msg.value;
  }

}
