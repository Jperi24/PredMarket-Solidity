// SPDX-License-Identifier: MIT
// 1. Pragma
pragma solidity ^0.8.20;
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";


contract predMarket2 is ReentrancyGuard {

    address public immutable owner;
    address private immutable staffWallet = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
   

   

    uint256 public endOfVoting;
    uint256 endTime;
    uint256 public creatorLocked;
    uint8 public winner;
    address public disagreedUser;
    RaffleState private s_raffleState;
    mapping(address => uint256[])public betsByUser;
    



    
   


    event winnerDeclaredVotingStaff(uint8 winnerIs);
    event contractDeployed(uint256 timeStamp);
    event winnerDeclaredVoting(uint8 winnerIs,uint256 endedAtTime);
    event winnerFinalized(uint8 winnerIs);
    event userPlacedBet(address indexed sender, uint256 betPlacedValue);
    event userReducedBet(address indexed sender, uint256 betReduced);
    event userWithdrewBet(address indexed sender,string betAorB);
    event underReview();
    event newBetOffered();
    event shithappened();
    event BetUnlisted(uint indexed positionOfArray);
    event userVoted();
    

    enum RaffleState {
        OPEN,
        VOTING,
        UNDERREVIEW,
        SETTLED
    }
     

    
 

    constructor(uint256 _endTime) payable {
        creatorLocked = msg.value;
        owner = msg.sender;
        endTime = _endTime;
        s_raffleState = RaffleState.OPEN;


    }

    modifier onlyOwnerOrStaff() {
        require(msg.sender == owner || msg.sender == staffWallet, "Only the owner can call this function.");
        _;
    }





   

    struct bet {
        address deployer;
        uint256 amountDeployerLocked;
        address owner;
        uint256 amountBuyerLocked;
        uint256 amountToBuyFor;
        uint8 conditionForBuyerToWin;//0 a wins, 1 b wins, 2 draw
        bool selling;
        uint256 positionInArray;
    
        
    }

    bet[] public arrayOfBets;

    function sellANewBet(uint256 amountToBuy,uint8 conditionToWIn ) public payable nonReentrant{
        require(conditionToWIn > 0 && conditionToWIn <= 2);
        require(s_raffleState == RaffleState.OPEN);

        bet memory newBet = bet(msg.sender,msg.value, msg.sender,0,amountToBuy, conditionToWIn,true,arrayOfBets.length);
        betsByUser[msg.sender].push(arrayOfBets.length);
        arrayOfBets.push(newBet);
        emit shithappened();
    }

    function unlistBets(uint[] memory positionsOfArray) public nonReentrant{
        // Loop through each position provided in the array
        for (uint i = 0; i < positionsOfArray.length; i++) {
            uint position = positionsOfArray[i];
            // Check if the sender is the owner of the bet
            require(arrayOfBets[position].owner == msg.sender, "Caller is not the owner");
            // Check if the bet is currently marked as selling
            require(arrayOfBets[position].selling == true, "Bet is not for sale");
            // Mark the bet as not selling
            arrayOfBets[position].selling = false;
            // Emit an event for the unlisted bet
            
        }
        emit shithappened();
    }

 

    function buyABet(uint positionOfArray) public payable nonReentrant{
        require(s_raffleState == RaffleState.OPEN);
        require(msg.value == arrayOfBets[positionOfArray].amountToBuyFor);
        require(arrayOfBets[positionOfArray].selling == true);
        if(arrayOfBets[positionOfArray].amountBuyerLocked ==0){
            arrayOfBets[positionOfArray].amountBuyerLocked = msg.value;
        }else{
             payable(arrayOfBets[positionOfArray].owner).transfer(msg.value);
        }
        betsByUser[msg.sender].push(positionOfArray);
        arrayOfBets[positionOfArray].owner = msg.sender;
        arrayOfBets[positionOfArray].selling = false;
        betsByUser[msg.sender].push(positionOfArray);
        emit shithappened();

    }

    function sellAnExistingBet(uint positionOfArray, uint newAskingPrice)public nonReentrant{
        require(s_raffleState == RaffleState.OPEN);
        require(arrayOfBets[positionOfArray].owner == msg.sender);
        arrayOfBets[positionOfArray].amountToBuyFor = newAskingPrice;
        arrayOfBets[positionOfArray].selling = true;
        emit shithappened();
    }

  

    event PayoutProcessed();
    event FundsRedistributed(address indexed beneficiary, uint amount);

    
    

    function declareWinner(uint8 _winner,uint8 disagreeCorrect)public onlyOwnerOrStaff nonReentrant{
        require((_winner>0) && (_winner < 4));
        if(msg.sender == owner){
            require(s_raffleState == RaffleState.OPEN);
            uint256 currentTime = block.timestamp;
            // endOfVoting = currentTime + 7200;
            endOfVoting = currentTime + 7200;
            s_raffleState = RaffleState.VOTING;
            winner = _winner;
            emit winnerDeclaredVoting(_winner,currentTime);
           
        }
        else{
            require(s_raffleState == RaffleState.UNDERREVIEW);
            if(disagreeCorrect == 1){
                payable(disagreedUser).transfer(creatorLocked);
            }
            winner = _winner;
            emit winnerDeclaredVotingStaff(_winner);
            s_raffleState = RaffleState.SETTLED;
        }   
    }



    function disagreeWithOwner()public payable nonReentrant{
        require((s_raffleState == RaffleState.VOTING && block.timestamp < endOfVoting) || (s_raffleState == RaffleState.OPEN && block.timestamp > endTime), "Invalid state or time");
        require(msg.value == creatorLocked);
        disagreedUser = msg.sender;
        s_raffleState = RaffleState.UNDERREVIEW;
        creatorLocked += msg.value;
        emit userVoted();
    }

    function allBets_Balance() public view returns (bet[] memory, uint256, uint8, RaffleState, uint256, uint256) {
    uint256 betterBalanceNew = 0;
    uint256 totalForCreatorCalculation = 0;  // To accumulate balance eligible for creator's take
    uint256 creatorTake = 0;  // Variable to store the potential owner's take
    uint256[] storage userBets = betsByUser[msg.sender]; // Direct access to save on gas

    if (winner > 0) {
        if (winner == 3) {
            for (uint i = 0; i < userBets.length; i++) {
                uint betIndex = userBets[i];
                bet storage currentBet = arrayOfBets[betIndex];
                if (currentBet.owner == msg.sender) {
                    betterBalanceNew += currentBet.amountBuyerLocked;
                }
                if (currentBet.deployer == msg.sender) {
                    betterBalanceNew += currentBet.amountDeployerLocked;
                }
            }
        } else {
            for (uint i = 0; i < userBets.length; i++) {
                uint betIndex = userBets[i];
                bet storage currentBet = arrayOfBets[betIndex];
                if (currentBet.owner == msg.sender && currentBet.conditionForBuyerToWin == winner) {
                    betterBalanceNew += currentBet.amountBuyerLocked + currentBet.amountDeployerLocked;
                    totalForCreatorCalculation += currentBet.amountBuyerLocked + currentBet.amountDeployerLocked;
                } else if (currentBet.deployer == msg.sender && currentBet.conditionForBuyerToWin != winner) {
                    betterBalanceNew += currentBet.amountBuyerLocked + currentBet.amountDeployerLocked;
                    totalForCreatorCalculation += currentBet.amountBuyerLocked + currentBet.amountDeployerLocked;
                } else if (currentBet.deployer == msg.sender && currentBet.amountToBuyFor == 0) {
                    betterBalanceNew += currentBet.amountDeployerLocked;
                    // Do not add to totalForCreatorCalculation, no fee should be deducted in this case
                }
            }
            // Calculate potential owner's take for the 'else' branch excluding specific condition
            if (totalForCreatorCalculation > 0) {
                creatorTake = totalForCreatorCalculation * 3 / 100;
            }
        }
    }
    
    // Ensure these variables are declared and properly managed within your contract
    return (arrayOfBets, endTime, winner, s_raffleState, endOfVoting, betterBalanceNew);
}


    

   function withdraw() public nonReentrant {
    require((s_raffleState ==RaffleState.SETTLED) || (s_raffleState == RaffleState.VOTING && block.timestamp > endOfVoting));


    uint256[] storage userBets = betsByUser[msg.sender];
    
    require(userBets.length>0);
  
    uint256 betterBalanceNew = 0;
    uint256 creatorPay;

    if (winner == 3) {
        for (uint i = 0; i < userBets.length; i++) {
            uint betIndex = userBets[i];
            bet storage currentBet = arrayOfBets[betIndex]; // Access the bet directly from storage
            if (currentBet.owner == msg.sender) {
                betterBalanceNew += currentBet.amountBuyerLocked;
                currentBet.amountBuyerLocked = 0; // Reset to prevent re-withdrawal
            }
            if (currentBet.deployer == msg.sender) {
                betterBalanceNew += currentBet.amountDeployerLocked;
                currentBet.amountDeployerLocked = 0;
            }
        }
        require(address(this).balance >= betterBalanceNew, "Contract does not have enough funds");
        payable(msg.sender).transfer(betterBalanceNew);
    } 
    else {
        for (uint i = 0; i < userBets.length; i++) {
            uint betIndex = userBets[i];
            bet storage currentBet = arrayOfBets[betIndex];
            if (currentBet.owner == msg.sender && currentBet.conditionForBuyerToWin == winner) {
                betterBalanceNew += currentBet.amountBuyerLocked + currentBet.amountDeployerLocked;
                creatorPay += currentBet.amountBuyerLocked + currentBet.amountDeployerLocked;
                currentBet.amountBuyerLocked = 0;
                currentBet.amountDeployerLocked = 0;
            } else if (currentBet.deployer == msg.sender && currentBet.conditionForBuyerToWin != winner) {
                betterBalanceNew += currentBet.amountBuyerLocked + currentBet.amountDeployerLocked;
                creatorPay += currentBet.amountBuyerLocked + currentBet.amountDeployerLocked;
                currentBet.amountBuyerLocked = 0;
                currentBet.amountDeployerLocked = 0;
            } else if (currentBet.deployer == msg.sender && currentBet.owner == msg.sender) {
                betterBalanceNew += currentBet.amountDeployerLocked;
                currentBet.amountDeployerLocked = 0;
               
            }
        }


        // Update balances
        uint256 amountToTransfer = betterBalanceNew - (creatorPay *3/100);
        if (creatorPay > 0) {
            creatorLocked += (creatorPay*3/100); // Ensure this state variable is declared in your contract
        }
        require(address(this).balance >= amountToTransfer, "Contract does not have enough funds");
        payable(msg.sender).transfer(amountToTransfer);
    }

}

    function transferOwnerAmount()public onlyOwnerOrStaff nonReentrant{
        require((s_raffleState == RaffleState.VOTING && block.timestamp > endOfVoting), "Invalid state or time");
        payable(owner).transfer(creatorLocked);
    }

    


  


    function isOwner() public view returns(bool){
        if((msg.sender == owner)||(msg.sender==staffWallet)){
            return true;
        }else{
            return false;
        }
    }


 

}



