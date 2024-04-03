// SPDX-License-Identifier: MIT
// 1. Pragma
pragma solidity ^0.8.20;
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";


contract predMarket2 is ReentrancyGuard {

    address private immutable owner;
    address private immutable staffWallet = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
   

   

    uint256 public endTime;
    uint256 public startTime;
    uint256 public voteTime;
    uint8 public winner;



    mapping(address => uint256)public betterBalance;
   



    event contractDeployed(uint256 timeStamp);
    event winnerDeclaredVoting(uint8 winnerIs, uint256 votingTime);
    event winnerFinalized(uint8 winnerIs);
    event userPlacedBet(address indexed sender, uint256 betPlacedValue);
    event userReducedBet(address indexed sender, uint256 betReduced);
    event userWithdrewBet(address indexed sender,string betAorB);
    event underReview();
    event newBetOffered();
    event shithappened();
    
    

     

    
 

    constructor(uint256 timeToEnd) payable {
     
    
        startTime = block.timestamp;
        endTime = startTime +timeToEnd;
        owner = msg.sender;
 
        emit contractDeployed(startTime);


    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only the owner can call this function.");
        _;
    }
    modifier onlyStaff(){
        require(msg.sender == staffWallet);
        _;
    }

    modifier ownerOrStaff(){
        require(msg.sender ==owner || msg.sender == staffWallet);
        _;
    }




   

    struct bet {
        address deployer;
        uint256 amountDeployerLocked;
        address owner;
        uint256 amountToBuyFor;
        uint8 conditionForBuyerToWin;//0 a wins, 1 b wins, 2 draw
        bool selling;
        uint256 positionInArray;
    
        
    }

     bet[] public arrayOfBets;

    function sellANewBet(uint256 amountToBuy,uint8 conditionToWIn ) public payable{
        require(conditionToWIn >= 0 && conditionToWIn <= 2);

        bet memory newBet = bet(msg.sender,msg.value, msg.sender,amountToBuy, conditionToWIn,true,arrayOfBets.length);
        arrayOfBets.push(newBet);
        emit shithappened();
    }

    function unlistABet(uint positionOfArray)public{
        require(arrayOfBets[positionOfArray].owner == msg.sender);
        require(arrayOfBets[positionOfArray].selling == true);
        arrayOfBets[positionOfArray].selling = false;
        emit shithappened();
    }

    // function listBet(uint positionOfArray)public{
    //     require(arrayOfBets[positionOfArray].owner == msg.sender);
    //     require(arrayOfBets[positionOfArray].selling == false);
    //     arrayOfBets[positionOfArray].selling = true;
    //     emit shithappened();
    // }

    function buyABet(uint positionOfArray) public payable{
        require(msg.value == arrayOfBets[positionOfArray].amountToBuyFor);
        require(arrayOfBets[positionOfArray].selling == true);
        betterBalance[arrayOfBets[positionOfArray].owner] += msg.value;
        arrayOfBets[positionOfArray].owner = msg.sender;
        arrayOfBets[positionOfArray].selling = false;
        emit shithappened();

    }

    function sellAnExistingBet(uint positionOfArray, uint newAskingPrice)public{
        require(arrayOfBets[positionOfArray].owner == msg.sender);
        arrayOfBets[positionOfArray].amountToBuyFor = newAskingPrice;
        arrayOfBets[positionOfArray].selling = true;
        emit shithappened();
    }

    function redeemBets()public onlyOwner{
        uint i = 0;
        while(i<arrayOfBets.length){
            if(arrayOfBets[i].conditionForBuyerToWin == winner){
                //if the current owner wins the bet
                betterBalance[arrayOfBets[i].owner] += arrayOfBets[i].amountDeployerLocked;
                i++;
            }
            else{
                betterBalance[arrayOfBets[i].deployer] += arrayOfBets[i].amountDeployerLocked;
                i++;
            }
        }
        emit shithappened();
    }

    function allBets_Balance() public view returns(bet[] memory,uint256){
        uint256 balance = betterBalance[msg.sender];
        return (arrayOfBets,balance);

    }

    function view_AllBets_YourBalance_YourBets() public view returns(bet[] memory allBets, uint256 myBalance,bet[] memory deployerBets, bet[] memory betterBets, uint256 totalLockedInDeployed, uint256 totalToWin) {
        uint deployerCount = 0;
        uint betterCount = 0;

        // First pass to count
        for (uint i = 0; i < arrayOfBets.length; i++) {
            if (arrayOfBets[i].deployer == msg.sender) {
                deployerCount++;
            } else if (arrayOfBets[i].owner == msg.sender) {
                betterCount++;
            }
        }

        // Allocate memory arrays
        bet[] memory tempDeployerArray = new bet[](deployerCount);
        bet[] memory tempBetterArray = new bet[](betterCount);

        // Second pass to populate
        uint deployerIndex = 0;
        uint betterIndex = 0;

        for (uint i = 0; i < arrayOfBets.length; i++) {
            if (arrayOfBets[i].deployer == msg.sender) {
                tempDeployerArray[deployerIndex] = arrayOfBets[i];
                totalLockedInDeployed += arrayOfBets[i].amountDeployerLocked;
                deployerIndex++;
            } else if (arrayOfBets[i].owner == msg.sender) {
                tempBetterArray[betterIndex] = arrayOfBets[i];
                totalToWin += arrayOfBets[i].amountDeployerLocked;
                betterIndex++;
            }
        }

        uint256 balance = betterBalance[msg.sender];

        return (arrayOfBets,balance,tempDeployerArray, tempBetterArray, totalLockedInDeployed, totalToWin);
    }


   
    



    function withdraw() public nonReentrant {
        payable(msg.sender).transfer(betterBalance[msg.sender]);
        
    }
   

   function getBalance() public view returns (uint) {
        return address(this).balance;
    }


  


    function isOwner() public view returns(bool){
        if((msg.sender == owner)||(msg.sender==staffWallet)){
            return true;
        }else{
            return false;
        }
    }



  

    

    

}



