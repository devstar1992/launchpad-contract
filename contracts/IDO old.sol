//SPDX-License-Identifier: MIT
pragma solidity 0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./IPool.sol";
import "./Pool.sol";
import "./DeployLibrary.sol";
contract IDO is Ownable {
  using SafeMath for uint256;
  using SafeMath for uint32;
  using SafeMath for uint16;
  using SafeMath for uint8;

  address[] public poolAddresses;
  uint256 public poolFixedFee;
  uint8 public poolPercentFee;
  struct PoolModel {  
    uint256 hardCap; // how much project wants to raise
    uint256 softCap; // how much of the raise will be accepted as successful IDO
    uint32 presaleRate;
    uint8 dexCapPercent;
    uint32 dexRate;
  }

  struct PoolDetails {
    uint256 startDateTime;
    uint256 endDateTime;
    uint256 minAllocationPerUser;
    uint256 maxAllocationPerUser;    
    uint8 dexLockup;
    bool refund;
    bool whitelistable;
  }

  event LogPoolCreated(address indexed poolOwner, address pool);

  modifier _feeEnough() {
    require(
      msg.value >= poolFixedFee,
      "Not enough fee!"
    );
    _;
  }

  function createPool(
    PoolModel calldata model,
    PoolDetails calldata details,   
    address _projectTokenAddress,
    bytes20 _extraData
  )
    external
    payable
    _feeEnough
    returns (address poolAddress)
  {
    // bytes memory bytecode = type(Pool).creationCode;
    // bytes32 salt = keccak256(abi.encodePacked(msg.sender, model.projectTokenAddress));
    // assembly {
    //     poolAddress := create2(0, add(bytecode, 32), mload(bytecode), salt)
    // }
    // IPool(poolAddress).setPoolModel(IPool.PoolModel({
    //   hardCap: model.hardCap.mul(10**17),
    //   softCap: model.softCap.mul(10**17),      
    //   projectTokenAddress:model.projectTokenAddress,      
    //   presaleRate:model.presaleRate,
    //   dexCapPercent:model.dexCapPercent,
    //   dexRate:model.dexRate,     
    //   kyc:false,
    //   kycData:"",
    //   status: IPool.PoolStatus(0)
    // }), 
    // IPool.PoolDetails({
    //   startDateTime: details.startDateTime,
    //   endDateTime: details.endDateTime,
    //   minAllocationPerUser:details.minAllocationPerUser.mul(10**17),
    //   maxAllocationPerUser:details.maxAllocationPerUser.mul(10**17),
    //   dexLockup:details.dexLockup,
    //   extraData:_extraData,
    //   refund:details.refund,
    //   whitelistable:details.whitelistable
    // }), owner(), msg.sender, poolPercentFee);
    // IERC20Metadata projectToken = IERC20Metadata(model.projectTokenAddress);
    // uint256 totalTokenAmount=model.hardCap.mul(model.presaleRate).add(model.hardCap.mul(model.dexRate.mul(model.dexCapPercent))/100);
    // totalTokenAmount=totalTokenAmount.mul(10**projectToken.decimals())/10;

    // projectToken.transferFrom(msg.sender, poolAddress, totalTokenAmount);
    // //pay for the project owner
    // projectToken.transferFrom(msg.sender, owner(), totalTokenAmount.mul(poolPercentFee)/100);
    poolAddress=DeployLibrary.deployPool(
      IPool.PoolModel({
      hardCap: model.hardCap.mul(10**17),
      softCap: model.softCap.mul(10**17),      
      projectTokenAddress:_projectTokenAddress,      
      presaleRate:model.presaleRate,
      dexCapPercent:model.dexCapPercent,
      dexRate:model.dexRate,     
      kyc:false,
      kycData:"",
      status: IPool.PoolStatus(0)
    }), 
    IPool.PoolDetails({
      startDateTime: details.startDateTime,
      endDateTime: details.endDateTime,
      minAllocationPerUser:details.minAllocationPerUser.mul(10**17),
      maxAllocationPerUser:details.maxAllocationPerUser.mul(10**17),
      dexLockup:details.dexLockup,
      extraData:_extraData,
      refund:details.refund,
      whitelistable:details.whitelistable
    }), owner(), msg.sender, poolPercentFee);
    payable(owner()).transfer(msg.value);
    
    poolAddresses.push(poolAddress);
    emit LogPoolCreated(msg.sender, poolAddress);
  }

  function setAdminFee(uint256 _poolFixedFee, uint8 _poolPercentFee)
  public
  onlyOwner()
  {
    poolFixedFee=_poolFixedFee;
    poolPercentFee=_poolPercentFee;
  }

  function removePool(address pool)
    external
    onlyOwner
  {
    for (uint index=0; index<poolAddresses.length; index++) {
      if(poolAddresses[uint(index)]==pool){
        for (uint i = index; i<poolAddresses.length-1; i++){
            poolAddresses[i] = poolAddresses[i+1];
        }
        delete poolAddresses[poolAddresses.length-1];
        break;
      }
    }
  }
}
