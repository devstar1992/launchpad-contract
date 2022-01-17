//SPDX-License-Identifier: MIT
pragma solidity 0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./IPool.sol";
import "./Pool.sol";
library DeployLibrary {
  using SafeMath for uint256;
  using SafeMath for uint32;
  using SafeMath for uint16;
  using SafeMath for uint8;

  function deployPool(
    IPool.PoolModel calldata _pool, 
    IPool.PoolDetails calldata _details, 
    address _admin, 
    uint8 _poolPercentFee,
    uint8 _poolTokenPercentFee
  )
    public 
    returns (address poolAddress)
  {
    bytes memory bytecode = type(Pool).creationCode;
    bytes32 salt = keccak256(abi.encodePacked(msg.sender, _pool.projectTokenAddress));
    assembly {
        poolAddress := create2(0, add(bytecode, 32), mload(bytecode), salt)
    }
    IPool(poolAddress).setPoolModel(_pool, _details, _admin, msg.sender, _poolPercentFee);
    IERC20Metadata projectToken = IERC20Metadata(_pool.projectTokenAddress);
    uint256 totalTokenAmount=_pool.hardCap.mul(_pool.presaleRate).add(_pool.hardCap.mul(_pool.dexRate.mul(_pool.dexCapPercent))/100);
    totalTokenAmount=totalTokenAmount.div(10**18);
    totalTokenAmount=totalTokenAmount.add(totalTokenAmount.mul(_poolTokenPercentFee)/100);
    if(totalTokenAmount>0)
      projectToken.transferFrom(msg.sender, poolAddress, totalTokenAmount);
    require(projectToken.balanceOf(poolAddress)==totalTokenAmount, "remove tax");
    //pay for the project owner
    // if(_poolTokenPercentFee>0)
    //   projectToken.transferFrom(msg.sender, _admin, totalTokenAmount.mul(_poolTokenPercentFee)/100);
    return poolAddress;
  }
  

 
}
