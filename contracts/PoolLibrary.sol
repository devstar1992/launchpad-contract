//SPDX-License-Identifier: MIT
pragma solidity 0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import "./IPool.sol";
library PoolLibrary {
  using SafeMath for uint256;
  using SafeMath for uint32;
  using SafeMath for uint16;
  using SafeMath for uint8;
  function _preValidatePoolDetails(IPool.PoolDetails memory _poolDetails) public view {  
    require(
      //solhint-disable-next-line not-rely-on-time
      _poolDetails.startDateTime >= block.timestamp,"startDate fail!"
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
  function _preValidatePoolCreation(IPool.PoolModel memory _pool, address _poolOwner, uint8 _poolPercentFee) public pure {
    require(_pool.hardCap > 0, "hardCap > 0");
    require(_pool.softCap > 0, "softCap > 0");
    require(_pool.softCap < _pool.hardCap, "softCap < hardCap");
    require(
      address(_poolOwner) != address(0),
      "Owner is a zero address!"
    );
    require(_pool.dexCapPercent >= 51 && _pool.dexCapPercent < 100, "dexCapPercent is 51~99%");
    require(_pool.dexRate > 0, "dexRate > 0!");
    require(_pool.presaleRate > 0, "presaleRate > 0!");
    require(_poolPercentFee >= 0 && _poolPercentFee<100, "percentFee!");
  }

  function _poolIsOngoing(IPool.PoolDetails storage _poolDetails) public view {   
    // solhint-disable-next-line not-rely-on-time
    require(_poolDetails.startDateTime <= block.timestamp, "not started");
    // solhint-disable-next-line not-rely-on-time
    require(_poolDetails.endDateTime >= block.timestamp, "end!");
  }



  function _poolIsReadyUpdate(IPool.PoolModel storage _pool) public view {
    require(
      _pool.status!= IPool.PoolStatus.Cancelled && _pool.status!= IPool.PoolStatus.Ended,
      "already cancelled!"
    );
  }

  function _poolIsCancelled(IPool.PoolModel storage _pool, IPool.PoolDetails storage _poolDetails, uint256 _weiRaised) public view {
    require(
      _pool.status== IPool.PoolStatus.Cancelled || 
      ((_pool.status== IPool.PoolStatus.Upcoming || _pool.status== IPool.PoolStatus.Inprogress || 
      _pool.status== IPool.PoolStatus.Finished) 
      && _poolDetails.endDateTime+7 days<= block.timestamp) || 
      ((_pool.status== IPool.PoolStatus.Upcoming || _pool.status== IPool.PoolStatus.Inprogress) && 
      _poolDetails.endDateTime<= block.timestamp && _pool.softCap>_weiRaised),
      "not cancelled!"
    );
  }

  function _poolIsReadyEnd(IPool.PoolModel storage _pool, IPool.PoolDetails storage _poolDetails, uint256 _weiRaised) public view {
    require(
      ( _poolDetails.endDateTime <= block.timestamp && _pool.status== IPool.PoolStatus.Inprogress && _pool.softCap<=_weiRaised ) ||
      _pool.status== IPool.PoolStatus.Finished,
      "not Ended!"
    );
  }

  function _poolIsEnded(IPool.PoolModel storage _pool, IPool.PoolDetails storage _poolDetails) public view {
    require(
      _pool.status== IPool.PoolStatus.Ended, "not Ended!"
    );
  }

  function _poolIsReadyUnlock(IPool.PoolModel storage _pool, IPool.PoolDetails storage _poolDetails) public view {
    require(
      _poolDetails.endDateTime+_poolDetails.dexLockup*1 days<= block.timestamp && _pool.status== IPool.PoolStatus.Ended,
      "lockup!"
    );
  }
}