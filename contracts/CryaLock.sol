//SPDX-License-Identifier: MIT
pragma solidity  ^0.8.8;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./CryaToken.sol";

contract CryaLock{
    using SafeMath for uint256;

    address public admin;
    uint64 immutable tgeTime;

    enum AddressType{
      SaftRound,
      StrategicSupporter,
      Ecology,
      IDOPublicOffering,
      Consultant,
      NftSale,
      Team
    }

    struct addressInfo{
      uint8 addressType;
      uint256 totalLocked;
      uint256 lockedLeft;  //need to update
      uint64 releaseStartTime;
      uint64 lastUpdateTime;    //need to update
      uint64 releaseEndTime;
    }

    mapping(address => addressInfo) addressInfos;
    address[] internal addresses = new address[](0);

    mapping(AddressType => uint256) public distributionRatios;
    mapping(AddressType => uint256) public distributionRatiosUsed;  //need to update

    uint256 immutable tokenTotalSupply;
    CryaToken public token;

    event Release(address beneficiary, uint256 amount);
    event LockBalance(address beneficiary, uint256 amount);

    constructor(uint64 _tgeTime){
        tgeTime = _tgeTime;
        admin = msg.sender;
        tokenTotalSupply = token.totalSupply(); 
        initDistributionRatio();
    }

    modifier onlyAdmin() {
        require(msg.sender == admin, "caller must be admin");
        _;
    }

    function initDistributionRatio()private{
        distributionRatios[AddressType.SaftRound] = tokenTotalSupply.mul(15).div(100);
        distributionRatiosUsed[AddressType.SaftRound] = 0;

        distributionRatios[AddressType.StrategicSupporter] = tokenTotalSupply.mul(16).div(100);
        distributionRatiosUsed[AddressType.StrategicSupporter] = 0;

        distributionRatios[AddressType.Ecology] = tokenTotalSupply.mul(39).div(100);
        distributionRatiosUsed[AddressType.Ecology] = 0;

        distributionRatios[AddressType.IDOPublicOffering] = tokenTotalSupply.mul(4).div(100);
        distributionRatiosUsed[AddressType.IDOPublicOffering] = 0;

        distributionRatios[AddressType.Consultant] = tokenTotalSupply.mul(6).div(100);
        distributionRatiosUsed[AddressType.Consultant] = 0;

        distributionRatios[AddressType.NftSale] = tokenTotalSupply.mul(5).div(100);
        distributionRatiosUsed[AddressType.NftSale] = 0;

        distributionRatios[AddressType.Team] = tokenTotalSupply.mul(15).div(100);
        distributionRatiosUsed[AddressType.Team] = 0;
    }

    function addTGEAddresses(address[] calldata _accounts,uint8[] calldata _addressTypes,uint256[] calldata _lockBalances)public onlyAdmin{
        require(block.timestamp < tgeTime,"This function only called before tgeTime!");
        require(_accounts.length == _addressTypes.length,"Length not equal!");
        require(_addressTypes.length == _lockBalances.length,"Length not equal!");
        for (uint256 i = 0;i < _accounts.length;i++){
            uint256 availableDistribution = distributionRatios[AddressType(_addressTypes[i])]
                    .sub(distributionRatiosUsed[AddressType(_addressTypes[i])]);
            require(availableDistribution >= _lockBalances[i],"availableDistribution amount not enough!");

            (uint64 start,uint64 update,uint64 end) = calculateStartEndTime(AddressType(_addressTypes[i]));
            addressInfos[_accounts[i]] = addressInfo(_addressTypes[i],_lockBalances[i],_lockBalances[i],start,update,end);
            addresses.push(_accounts[i]);

            if(_addressTypes[i] == uint8(AddressType.SaftRound)){
                uint256 releaseAmount = _lockBalances[i].mul(5).div(100);
                release(_accounts[i],releaseAmount);
            }
            emit LockBalance(_accounts[i], addressInfos[_accounts[i]].lockedLeft);
        }
    }

    function releaseLockedBalance(uint8 _type) public onlyAdmin{
        require(_type >=0 && _type <=6,"Wrong type!");
        require(block.timestamp >= tgeTime,"TGE not start!");
        for (uint256 i = 0;i < addresses.length;i++){
            address user = addresses[i];
            require(addressInfos[user].releaseStartTime > 0 ,"Not a release address!");
            if (_type == addressInfos[user].addressType){
                require(block.timestamp >= addressInfos[user].releaseStartTime,"release not start!");
                uint256 releaseAmount = calculateReleaseAmount(user);
                require(releaseAmount >0,"Not a support type!");
                release(user,releaseAmount);
            }
        }
    }

    function calculateReleaseAmount(address user)private returns(uint256){
        uint8 userType = addressInfos[user].addressType;
        uint256 startTime = addressInfos[user].releaseStartTime;
        uint256 updateTime = addressInfos[user].lastUpdateTime;
        uint256 endTime = addressInfos[user].releaseEndTime;
        uint256 calTime = block.timestamp > endTime ? endTime : block.timestamp;
        uint256 everyTimeAmount;

        if (userType == uint8(AddressType.SaftRound)){
            //release in 18 months
            if(calTime > updateTime){
                everyTimeAmount = addressInfos[user].totalLocked.div(18);
            }
        }else if (userType == uint8(AddressType.Ecology)){
            if(calTime > updateTime){
                //25% locked release in 9 months 
                if(calTime < (startTime + 10 * 30 days)){
                    uint256 lockedBalance = addressInfos[user].totalLocked.mul(25).div(100);
                    everyTimeAmount = lockedBalance.div(9);             
                }else if (calTime > (startTime + 10 * 30 days)){    
                    //75% locked release in 48  months
                    uint256 lockedBalance = addressInfos[user].totalLocked.mul(75).div(100);
                    everyTimeAmount = lockedBalance.div(48);
                }
            } 
        }else if (userType == uint8(AddressType.IDOPublicOffering)){
            if(calTime > updateTime){
                if(calTime >= (startTime) && (addressInfos[user].totalLocked == addressInfos[user].lockedLeft)){
                    everyTimeAmount = addressInfos[user].totalLocked.mul(333).div(1000);
                    return everyTimeAmount;
                }else if (calTime > (updateTime + 31 days)){
                    uint256 lockedBalance = addressInfos[user].totalLocked.mul(667).div(1000);
                    everyTimeAmount = lockedBalance.div(2);
                }
            }     
        }else if (userType == uint8(AddressType.Consultant)){
            if(calTime > updateTime){
                everyTimeAmount = addressInfos[user].totalLocked.div(33);
            }
        }else if (userType == uint8(AddressType.Team)){
            if(calTime > updateTime){
                if(calTime >= (startTime) && (addressInfos[user].totalLocked == addressInfos[user].lockedLeft)){
                    everyTimeAmount = addressInfos[user].totalLocked.mul(20).div(100);
                    return everyTimeAmount;
                }else if (calTime > (updateTime + 31 days)){
                    uint256 lockedBalance = addressInfos[user].totalLocked.mul(80).div(100);
                    everyTimeAmount = lockedBalance.div(48);
                }
            }  
        }

        uint256 numbs = (calTime - updateTime).div(30 days);
        require(numbs > 0,"Release: Not a correct time to release!");
        addressInfos[user].lastUpdateTime = uint64(updateTime + numbs * 30 days);
        return everyTimeAmount * numbs;
    }

    function release(address to,uint256 releaseAmount)private {
        address from = address(this);
        uint256 avaiBalance = token.balanceOf(from);

        require(releaseAmount <= avaiBalance,"Balance not enough!");
        distributionRatiosUsed[AddressType(addressInfos[to].addressType)] += releaseAmount;

        require(addressInfos[to].lockedLeft >= releaseAmount);
        addressInfos[to].lockedLeft -= releaseAmount;
        if(block.timestamp > addressInfos[to].releaseStartTime){
            addressInfos[to].lastUpdateTime = uint64(block.timestamp);
        }
        
        token.transferFrom(from, to, releaseAmount);
        emit Release(to, releaseAmount);
    }

    function getLockedBalance(address account)public view returns(uint256){
        return addressInfos[account].lockedLeft;
    }

    function calculateStartEndTime(AddressType _addrType)private view returns(uint64 startTime,uint64 updateTime,uint64 endTime){
        if (_addrType == AddressType.SaftRound){
            startTime = tgeTime;
            updateTime = startTime;
            endTime = tgeTime + 18 * 30 days;   //18 month
        }else if (_addrType == AddressType.Ecology) {
            startTime = tgeTime + 3 * 30 days;
            updateTime = startTime;
            endTime = tgeTime + 60 * 30 days;   //(3 + 9 + 48) month
        }else if (_addrType == AddressType.IDOPublicOffering) {
            startTime = tgeTime + 1 days;
            updateTime = startTime;
            endTime = tgeTime + 2 * 30 days;    //2 month
        }else if (_addrType == AddressType.Consultant) {
            startTime = tgeTime + 3 * 30 days;
            updateTime = startTime;
            endTime = tgeTime + 36 * 30 days;   //(3 + 33) month
        }else if (_addrType == AddressType.Team) {
            startTime = tgeTime + 12 * 30 days;
            updateTime = startTime;
            endTime = tgeTime + 60 * 30 days;   //(12 + 48) month
        }else{
            startTime = 0;
            updateTime = 0;
            endTime = 0; 
        }
        return (startTime,updateTime,endTime);
    }
 
    //airDropStrategicSupporter
    //airDropNFTSale
    //or others
    function airDropTo(address to, uint256 amount) public onlyAdmin{
        address from = address(this);
        uint256 avaiBalance = token.balanceOf(from);

        require(amount <= avaiBalance,"Balance not enough!");
        token.transferFrom(from, to, amount);
    }
}