//SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;


import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./IPool.sol";
import "./DeployLibrary.sol";
contract IDO is Ownable {
  using SafeMath for uint256;
  using SafeMath for uint32;
  using SafeMath for uint16;
  using SafeMath for uint8;


  address[] public poolAddresses;
  uint256 public poolFixedFeeForCommon=0;
  uint256 public poolFixedFeeForGold=0;
  uint256 public poolFixedFeeForPlatinum=0;
  uint256 public poolFixedFeeForDiamond=0;
  uint8 public poolPercentFee=0;
  uint8 public poolTokenPercentFee=0;
  mapping(address => address) public poolOwners;
  struct PoolModel {  
    uint256 hardCap; // how much project wants to raise
    uint256 softCap; // how much of the raise will be accepted as successful IDO
    uint256 presaleRate;
    uint8 dexCapPercent;
    uint256 dexRate;
    uint8 tier;
  }

  struct PoolDetails {
    uint256 startDateTime;
    uint256 endDateTime;
    uint256 minAllocationPerUser;
    uint256 maxAllocationPerUser;    
    uint16 dexLockup;
    // bool refund;
    bool whitelistable;
  }

  event LogPoolCreated(address poolOwner, address pool);
  event LogPoolKYCUpdate(address pool, bool kyc);
  event LogPoolTierUpdate(address pool, uint8 tier);
  event LogPoolAuditUpdate(address pool, bool audit);
  event LogPoolExtraData(address pool, string _extraData);
  event LogDeposit(address pool, address participant, uint256 amount);
  event LogPoolStatusChanged(address pool, uint256 status);  
  event LogFeeChanged(uint256 poolFixedFeeForCommon,
  uint256 poolFixedFeeForGold,
  uint256 poolFixedFeeForPlatinum,
  uint256 poolFixedFeeForDiamond, uint8 poolPercentFee, uint8 poolTokenPercentFee);  
  event LogPoolRemoved(address pool);  
  event LogAddressWhitelisted(address pool, address[] whitelistedAddresses);

  modifier _feeEnough(uint8 tier) {
    require(
      (msg.value >= poolFixedFeeForCommon && tier==0) || 
      (msg.value >= poolFixedFeeForGold && tier==1) ||
      (msg.value >= poolFixedFeeForPlatinum && tier==2) ||
      (msg.value >= poolFixedFeeForDiamond && tier==3),
      "Not enough fee!"
    );
    _;
  }

  modifier _onlyPoolOwner(address _pool, address _owner) {
    require(
      poolOwners[_pool] == _owner,
      "Not Owner!"
    );
    _;
  }
  modifier _onlyPoolOwnerAndOwner(address _pool, address _owner) {
    require(
      poolOwners[_pool] == _owner || _owner==owner(),
      "Not Owner!"
    );
    _;
  }

  function createPool(
    PoolModel calldata model,
    PoolDetails calldata details,   
    address _projectTokenAddress,
    string memory _extraData
  )
    external
    payable
    _feeEnough(model.tier)
    returns (address poolAddress)
  {
    poolAddress=DeployLibrary.deployPool(
      IPool.PoolModel({
      hardCap: model.hardCap,
      softCap: model.softCap,      
      projectTokenAddress:_projectTokenAddress,      
      presaleRate:model.presaleRate,
      dexCapPercent:model.dexCapPercent,
      dexRate:model.dexRate,     
      kyc:false,
      audit:false,
      status: IPool.PoolStatus(0),
      tier: IPool.PoolTier(model.tier)
    }), 
    IPool.PoolDetails({
      startDateTime: details.startDateTime,
      endDateTime: details.endDateTime,
      minAllocationPerUser:details.minAllocationPerUser,
      maxAllocationPerUser:details.maxAllocationPerUser,
      dexLockup:details.dexLockup,
      extraData:_extraData,
      // refund:details.refund,
      whitelistable:details.whitelistable
    }), owner(), poolPercentFee, poolTokenPercentFee);
    if(msg.value>0)
      payable(owner()).transfer(msg.value);
    
    poolAddresses.push(poolAddress);
    poolOwners[poolAddress]=msg.sender;
    emit LogPoolCreated(msg.sender, poolAddress);
  }

  function setAdminFee(uint256 _poolFixedFeeForCommon,
  uint256 _poolFixedFeeForGold,
  uint256 _poolFixedFeeForPlatinum,
  uint256 _poolFixedFeeForDiamond,
   uint8 _poolPercentFee, uint8 _poolTokenPercentFee)
  public
  onlyOwner()
  {
    poolFixedFeeForCommon=_poolFixedFeeForCommon;
    poolFixedFeeForGold=_poolFixedFeeForGold;
    poolFixedFeeForPlatinum=_poolFixedFeeForPlatinum;
    poolFixedFeeForDiamond=_poolFixedFeeForDiamond;
    poolPercentFee=_poolPercentFee;
    poolTokenPercentFee=_poolTokenPercentFee;
    emit LogFeeChanged(poolFixedFeeForCommon, poolFixedFeeForGold,
    poolFixedFeeForPlatinum, poolFixedFeeForDiamond, poolPercentFee, poolTokenPercentFee);
  }

  function removePool(address pool)
    external
    onlyOwner()
  {
    // try IPool(pool).status() returns (IPool.PoolStatus status) {
    //   if(status!=IPool.PoolStatus.Cancelled && status!=IPool.PoolStatus.Finished && status!=IPool.PoolStatus.Ended)
    //     IPool(pool).cancelPool(); 
    // } catch {
    // }
    
    for (uint index=0; index<poolAddresses.length; index++) {
      if(poolAddresses[uint(index)]==pool){
        for (uint i = index; i<poolAddresses.length-1; i++){
            poolAddresses[i] = poolAddresses[i+1];
        }
        delete poolAddresses[poolAddresses.length-1];
        poolAddresses.pop();
        break;
      }
    }
    emit LogPoolRemoved(pool);
  }

  function updateExtraData(address _pool, string memory _extraData)
    external
    _onlyPoolOwner(_pool, msg.sender)
  {
    IPool(_pool).updateExtraData(_extraData);  
    emit LogPoolExtraData(_pool, _extraData);
  }

  function updateKYCStatus(address _pool, bool _kyc)
    external
    onlyOwner()
  {
    IPool(_pool).updateKYCStatus(_kyc);  
    emit LogPoolKYCUpdate(_pool, _kyc);
  }

  function updateTierStatus(address _pool, uint8 _tier)
    external
    onlyOwner()
  {
    IPool(_pool).updateTierStatus(IPool.PoolTier(_tier));  
    emit LogPoolTierUpdate(_pool, _tier);
  }


  function updateAuditStatus(address _pool, bool _audit)
    external
    onlyOwner()
  {
    IPool(_pool).updateAuditStatus(_audit);  
    emit LogPoolAuditUpdate(_pool, _audit);
  }


  function addAddressesToWhitelist(address _pool, address[] calldata whitelistedAddresses)
    external
    _onlyPoolOwner(_pool, msg.sender)
  {
    IPool(_pool).addAddressesToWhitelist(whitelistedAddresses); 
    emit LogAddressWhitelisted(_pool, whitelistedAddresses);
  }

  function deposit(address _pool)
    external
    payable
  {
    IPool(_pool).deposit{value: msg.value}(msg.sender); 
    emit LogDeposit(_pool, msg.sender, msg.value);
  }

  function cancelPool(address _pool)
    external
    _onlyPoolOwnerAndOwner(_pool, msg.sender)
  {
    IPool(_pool).cancelPool(); 
    emit LogPoolStatusChanged(_pool, uint(IPool.PoolStatus.Cancelled));
  }

  function claimToken(address _pool)
    external
  {
    IPool(_pool).claimToken(msg.sender); 
  }

  function refund(address _pool)
    external
  {
    IPool(_pool).refund(msg.sender); 
    emit LogPoolStatusChanged(_pool, uint(IPool.PoolStatus.Cancelled));
  }


  function endPool(address _pool)
    external
    _onlyPoolOwner(_pool, msg.sender)
  {
    IPool(_pool).endPool(); 
    emit LogPoolStatusChanged(_pool, uint(IPool.PoolStatus.Ended));
  }

  function unlockLiquidityDex(address _pool)
    external    
  {
    IPool(_pool).unlockLiquidityDex(); 
  }

}
