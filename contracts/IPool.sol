//SPDX-License-Identifier: MIT
pragma solidity 0.8.0;

interface IPool {
  event LogPoolKYCUpdate(bool kyc);
  event LogPoolAuditUpdate(bool audit);
  event LogPoolExtraData(string indexed _extraData);
  event LogDeposit(address indexed participant, uint256 amount);
  event LogPoolStatusChanged(uint256 status);  
  event LogPoolTierUpdate(uint8 tier);

  struct PoolModel {
    uint256 hardCap; // how much project wants to raise
    uint256 softCap; // how much of the raise will be accepted as successful IDO
    uint256 presaleRate;
    uint8 dexCapPercent;
    uint256 dexRate;
    address projectTokenAddress; //the address of the token that project is offering in return   
    PoolStatus status; //: by default “Upcoming”,
    PoolTier tier;
    bool audit;
    bool kyc;
  }

  struct PoolDetails {
    uint256 startDateTime;
    uint256 endDateTime;
    uint256 minAllocationPerUser;
    uint256 maxAllocationPerUser;    
    uint16 dexLockup;
    string extraData;
    // bool refund;
    bool whitelistable;
  }

  struct Participations {
    ParticipantDetails[] investorsDetails;
    uint256 count;
  }

  struct ParticipantDetails {
    address addressOfParticipant;
    uint256 totalRaisedInWei;
  }

  enum PoolStatus {
    Upcoming,
    Inprogress,
    Finished,
    Ended,
    Cancelled
  }
  enum PoolTier {
    Nothing,
    Gold,
    Platinum,
    Diamond
  }

  function setPoolModel(PoolModel calldata _pool, PoolDetails calldata _details, address _adminOwner, address _poolOwner, uint8 _poolETHFee)
    external;
  function updateExtraData(string memory _detailedPoolInfo) external;
  function updateKYCStatus(bool _kyc) external;
  function updateTierStatus(PoolTier _tier) external;
  function updateAuditStatus(bool _audit) external;
  function addAddressesToWhitelist(address[] calldata whitelistedAddresses) external;

  function deposit(address sender) external payable;
  function cancelPool() external;
  function claimToken(address claimer) external;
  function refund(address claimer) external;
  function endPool() external;
  function unlockLiquidityDex() external;
  function status() external view returns (PoolStatus);
  function endDateTime()  external view returns (uint256);
  function startDateTime()  external view returns (uint256);
}
