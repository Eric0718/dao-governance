//SPDX-License-Identifier: MIT
pragma solidity  ^0.8.8;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./CryaToken.sol";

contract CryaLock{
    using SafeMath for uint256;

    address public admin;
    uint256 immutable tgeTime;

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
      uint256 releaseStartTime;
      uint256 lastUpdateTime;    //need to update
      uint256 releaseEndTime;
    }

    mapping(address => addressInfo) addressInfos;
    address[] internal addresses = new address[](0);

    mapping(AddressType => uint256) public distributionRatios;
    mapping(AddressType => uint256) public distributionRatiosUsed;  //need to update

    uint256 immutable tokenTotalSupply;
    uint256 constant baseTimeInterval = 30 days;

    CryaToken public token;

    event Release(address beneficiary, uint256 amount);
    event LockBalance(address beneficiary, uint256 amount);

    constructor(uint256 _tgeTime){
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
        //SaftRound is 15% of tokenTotalSupply.
        distributionRatios[AddressType.SaftRound] = tokenTotalSupply.mul(15).div(100);
        distributionRatiosUsed[AddressType.SaftRound] = 0;

        //StrategicSupporter is 16% of tokenTotalSupply.
        distributionRatios[AddressType.StrategicSupporter] = tokenTotalSupply.mul(16).div(100);
        distributionRatiosUsed[AddressType.StrategicSupporter] = 0;

        //Ecology is 39% of tokenTotalSupply.
        distributionRatios[AddressType.Ecology] = tokenTotalSupply.mul(39).div(100);
        distributionRatiosUsed[AddressType.Ecology] = 0;
        
        //IDOPublicOffering is 4% of tokenTotalSupply.
        distributionRatios[AddressType.IDOPublicOffering] = tokenTotalSupply.mul(4).div(100);
        distributionRatiosUsed[AddressType.IDOPublicOffering] = 0;

        //Consultant is 6% of tokenTotalSupply.
        distributionRatios[AddressType.Consultant] = tokenTotalSupply.mul(6).div(100);
        distributionRatiosUsed[AddressType.Consultant] = 0;

        //NftSale is 5% of tokenTotalSupply
        distributionRatios[AddressType.NftSale] = tokenTotalSupply.mul(5).div(100);
        distributionRatiosUsed[AddressType.NftSale] = 0;

        //Team is 15% of tokenTotalSupply
        distributionRatios[AddressType.Team] = tokenTotalSupply.mul(15).div(100);
        distributionRatiosUsed[AddressType.Team] = 0;
    }

    //add addresses before TGE
    function addAddressesBeforeTge(address[] calldata _accounts,uint8[] calldata _addressTypes,uint256[] calldata _lockBalances)public onlyAdmin{
        require(block.timestamp < tgeTime,"This function only called before tgeTime!");
        require(_accounts.length == _addressTypes.length,"Length not equal!");
        require(_addressTypes.length == _lockBalances.length,"Length not equal!");
        for (uint256 i = 0;i < _accounts.length;i++){
            uint256 availableDistribution = distributionRatios[AddressType(_addressTypes[i])]
                    .sub(distributionRatiosUsed[AddressType(_addressTypes[i])]);
            require(availableDistribution >= _lockBalances[i],"availableDistribution amount not enough!");

            (uint256 start,uint256 update,uint256 end) = calculateStartEndTime(AddressType(_addressTypes[i]));
            addressInfos[_accounts[i]] = addressInfo(_addressTypes[i],_lockBalances[i],_lockBalances[i],start,update,end);
            distributionRatiosUsed[AddressType(_addressTypes[i])] += _lockBalances[i];
            addresses.push(_accounts[i]);
            emit LockBalance(_accounts[i], addressInfos[_accounts[i]].lockedLeft);
        }
    }

    //release locked balance by address type
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
        uint256 releaseAmount;

        if (userType == uint8(AddressType.SaftRound)){
            //release in 18 months
            if(calTime >= updateTime){
                if(addressInfos[user].totalLocked == addressInfos[user].lockedLeft){
                    return addressInfos[user].totalLocked.mul(5).div(100); 
                }
                releaseAmount = addressInfos[user].totalLocked.div(18);
            }
        }else if (userType == uint8(AddressType.Ecology)){
            if(calTime >= updateTime){
                //25% locked release in 9 months 
                if(calTime < (startTime + 10 * baseTimeInterval)){
                    uint256 lockedBalance = addressInfos[user].totalLocked.mul(25).div(100);
                    releaseAmount = lockedBalance.div(9);             
                }else if (calTime > (startTime + 10 * baseTimeInterval)){    
                    //75% locked release in 48  months
                    uint256 lockedBalance = addressInfos[user].totalLocked.mul(75).div(100);
                    releaseAmount = lockedBalance.div(48);
                }
            } 
        }else if (userType == uint8(AddressType.IDOPublicOffering)){
            if(calTime >= updateTime){
                //TGE +1 release 33.3%
                if(addressInfos[user].totalLocked == addressInfos[user].lockedLeft){
                    return addressInfos[user].totalLocked.mul(333).div(1000);
                }else if (calTime > (updateTime + baseTimeInterval)){
                    //66.7% release in two months
                    uint256 lockedBalance = addressInfos[user].totalLocked.mul(667).div(1000);
                    releaseAmount = lockedBalance.div(2);
                }
            }     
        }else if (userType == uint8(AddressType.Consultant)){
            //release in 33 months
            if(calTime >= updateTime){
                releaseAmount = addressInfos[user].totalLocked.div(33);
            }
        }else if (userType == uint8(AddressType.Team)){
            if(calTime >= updateTime){
                //20% release in a year
                if(addressInfos[user].totalLocked == addressInfos[user].lockedLeft){
                    return addressInfos[user].totalLocked.mul(20).div(100);
                }else if (calTime > (updateTime + baseTimeInterval)){
                    //80% release in 48 months
                    uint256 lockedBalance = addressInfos[user].totalLocked.mul(80).div(100);
                    releaseAmount = lockedBalance.div(48);
                }
            }  
        }else{
            revert("Not a correct type to release!");
        }

        uint256 numbs = (calTime - updateTime).div(baseTimeInterval);
        require(numbs > 0,"Release: Not a correct time to release!");
        addressInfos[user].lastUpdateTime = updateTime + numbs * baseTimeInterval;
        return releaseAmount * numbs;
    }

    function release(address to,uint256 releaseAmount)private {
        address from = address(this);
        uint256 avaiBalance = token.balanceOf(from);

        require(releaseAmount <= avaiBalance,"Balance not enough!");

        require(addressInfos[to].lockedLeft >= releaseAmount);
        addressInfos[to].lockedLeft -= releaseAmount;
        if(block.timestamp > addressInfos[to].releaseStartTime){
            addressInfos[to].lastUpdateTime = block.timestamp;
        }
        
        token.transferFrom(from, to, releaseAmount);
        emit Release(to, releaseAmount);
    }

    function getLockedBalance(address account)public view returns(uint256){
        return addressInfos[account].lockedLeft;
    }

    function calculateStartEndTime(AddressType _addrType)private view returns(uint256 startTime,uint256 updateTime,uint256 endTime){
        if (_addrType == AddressType.SaftRound){
            startTime = tgeTime;
            updateTime = startTime;
            endTime = tgeTime + 18 * baseTimeInterval;   //18 month
        }else if (_addrType == AddressType.Ecology) {
            startTime = tgeTime + 3 * baseTimeInterval;
            updateTime = startTime;
            endTime = tgeTime + 60 * baseTimeInterval;   //(3 + 9 + 48) month
        }else if (_addrType == AddressType.IDOPublicOffering) {
            startTime = tgeTime + 1 days;
            updateTime = startTime;
            endTime = tgeTime + 2 * baseTimeInterval;    //2 month
        }else if (_addrType == AddressType.Consultant) {
            startTime = tgeTime + 3 * baseTimeInterval;
            updateTime = startTime;
            endTime = tgeTime + 36 * baseTimeInterval;   //(3 + 33) month
        }else if (_addrType == AddressType.Team) {
            startTime = tgeTime + 12 * baseTimeInterval;
            updateTime = startTime;
            endTime = tgeTime + 60 * baseTimeInterval;   //(12 + 48) month
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
    function transferTo(address to, uint256 amount) public onlyAdmin{
        address from = address(this);
        uint256 avaiBalance = token.balanceOf(from);

        require(amount <= avaiBalance,"Balance not enough!");
        token.transferFrom(from, to, amount);
    }
}