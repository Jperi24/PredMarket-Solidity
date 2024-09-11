// SPDX-License-Identifier: MIT
// 1. Pragma
pragma solidity ^0.8.20;
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";


contract predMarket2 is ReentrancyGuard {

    address public immutable owner;

    address[] private staffWallets = [
        0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 // Add more addresses as needed
    ];


   
   uint256 public staffPay;

    modifier onlyStaff() {
        bool isStaff = false;
        for (uint256 i = 0; i < staffWallets.length; i++) {
            if (staffWallets[i] == msg.sender) {
                isStaff = true;
                break;
            }
        }
        require(isStaff, "Caller is not a staff member");
        _;
    }
    

   

    uint256 public endOfVoting;
    uint256 endTime;
    uint256 public creatorLocked;
    uint8 public winner;
    uint8 public disagreeCorrect;
    address public disagreedUser;
    RaffleState private s_raffleState;
    mapping(address => uint256[])public betsByUser;
    
    



    
   


    
 
   
    
    event userCreatedABet();
    event BetUnlisted();
    event userBoughtBet();
    event userReListedBet();
    event winnerDeclaredVoting();
    event userVoted();
    event userWithdrew();
    

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
        bool isStaff = false;
        for (uint256 i = 0; i < staffWallets.length; i++) {
            if (staffWallets[i] == msg.sender) {
                isStaff = true;
                break;
            }
        }
        require(msg.sender == owner || isStaff, "Caller is not the owner or a staff member");
        _;
    }







   

    struct bet {
        address deployer;
        uint256 amountDeployerLocked;
        address owner;
        uint256 amountBuyerLocked;
        uint256 amountToBuyFor;
        uint8 conditionForBuyerToWin;
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
        emit userCreatedABet();
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
        emit BetUnlisted();
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
        
        emit userBoughtBet();

    }
function editADeployedBet(
    uint positionOfArray, 
    uint newDeployPrice, 
    uint newAskingPrice
) 
    public 
    payable 
    nonReentrant 
{
    // Ensure only the deployer can edit the bet
    require(
        arrayOfBets[positionOfArray].owner == msg.sender && 
        arrayOfBets[positionOfArray].deployer == msg.sender, 
        "Only the deployer can edit this bet"
    );

    bet storage currentBet = arrayOfBets[positionOfArray];
    uint currentLockedAmount = currentBet.amountDeployerLocked;

    if (newDeployPrice != currentLockedAmount) {
        // Handle refund if the new deploy price is less than the current amount locked
        if (newDeployPrice < currentLockedAmount) {
            uint refundAmount = currentLockedAmount - newDeployPrice;
            require(address(this).balance >= refundAmount, "Contract does not have enough funds");
            currentBet.amountDeployerLocked = newDeployPrice;
            payable(msg.sender).transfer(refundAmount);
        } 
        // Handle additional funds required if the new deploy price is greater
        else {
            uint additionalAmount = newDeployPrice - currentLockedAmount;
            require(msg.value == additionalAmount, "Incorrect additional funds sent");
            currentBet.amountDeployerLocked = newDeployPrice;
        }
    }

    // Update the asking price
    currentBet.amountToBuyFor = newAskingPrice;

    // Ensure the bet is marked as selling if it wasn't already
    if (!currentBet.selling) {
        currentBet.selling = true;
    }
}



    function sellAnExistingBet(uint positionOfArray, uint newAskingPrice)public nonReentrant{
        require(s_raffleState == RaffleState.OPEN);
        require(arrayOfBets[positionOfArray].owner == msg.sender);
        arrayOfBets[positionOfArray].amountToBuyFor = newAskingPrice;
        arrayOfBets[positionOfArray].selling = true;
        emit userReListedBet();
    }

  

    event PayoutProcessed();
    event FundsRedistributed(address indexed beneficiary, uint amount);

    
    

    function declareWinner(uint8 _winner,uint8 _disagreeCorrect)public onlyOwnerOrStaff nonReentrant{
        require((_winner>0) && (_winner < 4));
        if(msg.sender == owner){
            require(s_raffleState == RaffleState.OPEN);
            uint256 currentTime = block.timestamp;
            endOfVoting = currentTime + 72;
            //endOfVoting = currentTime + 7200;
            s_raffleState = RaffleState.VOTING;
            winner = _winner;
            emit winnerDeclaredVoting();
           
        }
        else{
            require(s_raffleState == RaffleState.UNDERREVIEW);
            disagreeCorrect = _disagreeCorrect;
            if(_disagreeCorrect == 1){
                payable(disagreedUser).transfer(creatorLocked);
            }
            else if(_disagreeCorrect == 3){
                //transfer to staff money, set that up
                staffPay += creatorLocked;
            }

            winner = _winner;
            emit winnerDeclaredVoting();
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

    function allBets_Balance() public view returns (bet[] memory, uint256, uint8, RaffleState, uint256, uint256,uint256,uint256) {
        uint256 betterBalanceNew = 0;
        uint256 balanceIfWinnerIs1 = 0;
        uint256 balanceIfWinnerIs2 = 0;

    
        uint256[] storage userBets = betsByUser[msg.sender]; // Direct access to save on gas

        uint256 creatorPay = 0;
        bool isWinnerThree = winner == 3;
        bool isWinnerZero = winner ==0;

        for (uint256 i = 0; i < userBets.length; i++) {
            uint256 betIndex = userBets[i];
            bet storage currentBet = arrayOfBets[betIndex];

            // if(isWinnerZero){
            //     if (currentBet.deployer == msg.sender && currentBet.owner == msg.sender) {
            //             balanceIfWinnerIs1 += (currentBet.amountDeployerLocked + currentBet.amountBuyerLocked);
            //             balanceIfWinnerIs2 += (currentBet.amountDeployerLocked + currentBet.amountBuyerLocked);
            //         }
            //     else if (
            //         (currentBet.owner == msg.sender && currentBet.conditionForBuyerToWin == 1) ||
            //         (currentBet.deployer == msg.sender && currentBet.conditionForBuyerToWin == 2)
            //     ) {
            //         balanceIfWinnerIs1 += currentBet.amountBuyerLocked + currentBet.amountDeployerLocked;
            //         creatorPay += currentBet.amountBuyerLocked + currentBet.amountDeployerLocked;
                   
            //     }
            //     else if (
            //         (currentBet.owner == msg.sender && currentBet.conditionForBuyerToWin == 2) ||
            //         (currentBet.deployer == msg.sender && currentBet.conditionForBuyerToWin == 1)
            //     ) {
            //         balanceIfWinnerIs2 += currentBet.amountBuyerLocked + currentBet.amountDeployerLocked;
            //         creatorPay += currentBet.amountBuyerLocked + currentBet.amountDeployerLocked;
            //     }
                

            // }

            if(!isWinnerZero){

                if (isWinnerThree) {
                    if (currentBet.owner == msg.sender) {
                        betterBalanceNew += currentBet.amountBuyerLocked;
                    
                    }
                    if (currentBet.deployer == msg.sender) {
                        betterBalanceNew += currentBet.amountDeployerLocked;
                    
                    }
                } else {
                    if (currentBet.deployer == msg.sender && currentBet.owner == msg.sender) {
                        betterBalanceNew += (currentBet.amountDeployerLocked + currentBet.amountBuyerLocked);
                    }
                    else if (
                        (currentBet.owner == msg.sender && currentBet.conditionForBuyerToWin == winner) ||
                        (currentBet.deployer == msg.sender && currentBet.conditionForBuyerToWin != winner)
                    ) {
                        betterBalanceNew += currentBet.amountBuyerLocked + currentBet.amountDeployerLocked;
                        creatorPay += currentBet.amountBuyerLocked + currentBet.amountDeployerLocked;
                    
                    } 
                }
            }
            
        }
        if (!isWinnerThree && creatorPay > 0) {
            
                uint256 creatorFee = creatorPay * 5 / 100;
                betterBalanceNew -= creatorFee;

            }
            

        
        // Ensure these variables are declared and properly managed within your contract
        return (arrayOfBets, endTime, winner, s_raffleState, endOfVoting, betterBalanceNew,balanceIfWinnerIs1,balanceIfWinnerIs2);
    }


    

  function withdraw() public nonReentrant {
    require(
        (s_raffleState == RaffleState.SETTLED) || 
        (s_raffleState == RaffleState.VOTING && block.timestamp > endOfVoting)
    );

    uint256[] storage userBets = betsByUser[msg.sender];
    require(userBets.length > 0);

    uint256 betterBalanceNew = 0;
    uint256 creatorPay = 0;
    bool isWinnerThree = winner == 3;
    for (uint256 i = 0; i < userBets.length; i++) {
        uint256 betIndex = userBets[i];
        bet storage currentBet = arrayOfBets[betIndex];

        if (isWinnerThree) {
            if (currentBet.owner == msg.sender) {
                betterBalanceNew += currentBet.amountBuyerLocked;
                currentBet.amountBuyerLocked = 0;
            }
            if (currentBet.deployer == msg.sender) {
                betterBalanceNew += currentBet.amountDeployerLocked;
                currentBet.amountDeployerLocked = 0;
            }
        } else {
            bool isBothPartiesSame = currentBet.deployer == msg.sender && currentBet.owner == msg.sender;
            if (isBothPartiesSame) {
                betterBalanceNew += (currentBet.amountDeployerLocked + currentBet.amountBuyerLocked);
                currentBet.amountDeployerLocked = 0;
                currentBet.amountBuyerLocked = 0;
            }
            else if (
                (currentBet.owner == msg.sender && currentBet.conditionForBuyerToWin == winner) ||
                (currentBet.deployer == msg.sender && currentBet.conditionForBuyerToWin != winner)
            ) {
                uint256 totalLockedAmount = currentBet.amountBuyerLocked + currentBet.amountDeployerLocked;
                betterBalanceNew += totalLockedAmount;
                creatorPay += totalLockedAmount;
                currentBet.amountBuyerLocked = 0;
                currentBet.amountDeployerLocked = 0;
            } 
        }
    }

    if (!isWinnerThree && creatorPay > 0) {
        uint256 creatorFee = (creatorPay * 300) / 10000; 
        uint256 _staffPay = (creatorPay * 200) / 10000; 
        staffPay += _staffPay;
        creatorLocked += creatorFee;
        betterBalanceNew -= (creatorFee + _staffPay);
    }

    require(betterBalanceNew > 0, "No balance to withdraw");
    require(address(this).balance >= betterBalanceNew, "Insufficient contract balance");

    payable(msg.sender).transfer(betterBalanceNew);

    emit userWithdrew();
}


    function transferOwnerAmount()public onlyOwnerOrStaff nonReentrant{
        require(((s_raffleState == RaffleState.VOTING && block.timestamp > endOfVoting) || disagreeCorrect==2), "Invalid state or time");
        require(creatorLocked > 0);
        payable(owner).transfer(creatorLocked);
        creatorLocked = 0;

    }

    function transferStaffAmount()public onlyStaff nonReentrant{
        require(((s_raffleState == RaffleState.VOTING && block.timestamp > endOfVoting) || disagreeCorrect==2), "Invalid state or time");
        require(staffPay > 0);
        payable(msg.sender).transfer(staffPay);
        creatorLocked = 0;
    }

    

}



