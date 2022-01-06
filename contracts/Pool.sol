//SPDX-License-Identifier: MIT
pragma solidity 0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import "./IPool.sol";
import "./Validations.sol";
import "./Whitelist.sol";
import "./IPancakeRouter02.sol";
import "./PoolLibrary.sol";
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
    PoolLibrary._preValidatePoolCreation(_pool, _poolOwner, _poolPercentFee);
    poolInformation = _pool;
    PoolLibrary._preValidatePoolDetails(_details);
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

  modifier _poolIsReadyStart(PoolModel storage _pool, PoolDetails storage _poolDetails) {
    require(
      _poolDetails.startDateTime <= block.timestamp && _pool.status!= IPool.PoolStatus.Cancelled && _pool.status!= IPool.PoolStatus.Ended && _pool.status!= IPool.PoolStatus.Finished,
      "not started!"
    );
    _;
  }

  modifier _poolIsReadyCancel(PoolModel storage _pool, PoolDetails storage _poolDetails) {
    require(
      _pool.status!= IPool.PoolStatus.Cancelled && _pool.status!= IPool.PoolStatus.Ended && _pool.status!= IPool.PoolStatus.Finished,
      "already cancelled!"
    );
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
    require(sum <= _hardCap, "hardCap!");
    require(sum > _beforeBalance, "hardCap overflow!");
    _;
  }

  modifier _minAllocationNotPassed(uint256 _minAllocationPerUser) {
    require(_minAllocationPerUser <= msg.value, "Less!");
    _;
  }

  modifier _maxAllocationNotPassed(uint256 _maxAllocationPerUser, address sender) {
    uint256 aa=collaborations[sender] + msg.value;

    require(aa <= _maxAllocationPerUser, "More!");
    _;
  }

  modifier _onlyWhitelisted(address sender) {
    require(!poolDetails.whitelistable || isWhitelisted(sender), "Not!");
    _;
  }

  function updateExtraData(string memory _extraData)
    external
    override    
    _onlyFactory
    _poolIsReadyCancel(poolInformation, poolDetails)
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
    _poolIsReadyCancel(poolInformation, poolDetails)
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
    _maxAllocationNotPassed(poolDetails.maxAllocationPerUser, sender)
    _hardCapNotPassed(poolInformation.hardCap)
  {
    uint256 _amount = msg.value;

    _increaseRaisedWEI(_amount);
    _addToParticipants(sender);
    emit LogDeposit(sender, _amount);
  }

  function startPool()
    external
    override
    _onlyFactory
    _poolIsReadyStart(poolInformation, poolDetails)    
  {    
    poolInformation.status=PoolStatus.Inprogress;
    emit LogPoolStatusChanged(uint(PoolStatus.Inprogress));
  }

  function cancelPool()
    external
    override
    _onlyFactory
    _poolIsReadyCancel(poolInformation, poolDetails) 
  {
    projectToken = IERC20Metadata(poolInformation.projectTokenAddress);
    for(uint i=0;i<participantsAddress.length;i++){
      uint256 refund=collaborations[address(participantsAddress[i])];
      collaborations[address(participantsAddress[i])]=0;
      address addr = participantsAddress[i];
      payable(addr).transfer(refund);      
    }
    poolInformation.status=PoolStatus.Cancelled;
    projectToken.transfer(address(poolOwner), projectToken.balanceOf(address(this)));
    emit LogPoolStatusChanged(uint(PoolStatus.Cancelled));
  }

  function refundPool()
    external
    override
    _onlyFactory
    _poolIsReadyEnd(poolInformation, poolDetails)    
  {
    projectToken = IERC20Metadata(poolInformation.projectTokenAddress);
    //distribute the token
    uint count=0;
    for(uint i=0;i<participantsAddress.length;i++){
      address _receiver = address(participantsAddress[i]);
      if(_didRefund[_receiver]== false){
        _didRefund[_receiver] = true;
        uint256 _amount = collaborations[_receiver].mul(poolInformation.presaleRate);    
        _amount=_amount.div(10**18);
        projectToken.transfer(_receiver, _amount);
        break;
      }
      count++;
    }
    assert(count<participantsAddress.length);
    
  }
  function endPool()
    external
    override
    _onlyFactory
    _poolIsReadyEnd(poolInformation, poolDetails)    
  {
    projectToken = IERC20Metadata(poolInformation.projectTokenAddress);

    //pay for the project owner
    uint256 toAdminETHAmount=_weiRaised.mul(poolPercentFee).div(100);
    payable(admin).transfer(toAdminETHAmount);      
    uint256 rest=_weiRaised.sub(toAdminETHAmount);
    // send ETH and Token back to the pool owner
    dexETHAmount=poolInformation.hardCap.mul(poolInformation.dexCapPercent).mul(poolInformation.presaleRate).div(poolInformation.dexRate).div(100);
    if(dexETHAmount>=rest){
      dexETHAmount=rest;      
    }else{     
      payable(poolOwner).transfer(rest.sub(dexETHAmount));
    }
    dexTokenAmount=dexETHAmount.mul(poolInformation.dexRate).div(10**18); 
    //refund to the pool owner
    uint256 tokenRest=projectToken.balanceOf(address(this)).sub(dexTokenAmount);
    // if(poolDetails.refund==true)
      projectToken.transfer(address(poolOwner), tokenRest);
    // else
    //   projectToken.transfer(address(0), tokenRest);
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


 function status() 
    external override view
    returns (IPool.PoolStatus)
  {
    return poolInformation.status;
  }

  function endDateTime() 
    external override view
    returns (uint256)
  {
    return poolDetails.endDateTime;
  }

  function startDateTime() 
    external override view
    returns (uint256)
  {
    return poolDetails.startDateTime;
  }

  function _increaseRaisedWEI(uint256 _amount) private {
    require(_amount > 0, "No WEI found!");

    _weiRaised =_weiRaised.add(_amount);

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
    public
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
