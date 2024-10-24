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
    uint256 public creatorLocked;
    uint256 endTime;
    uint8 public winner;
    RaffleState public s_raffleState;
    mapping(address => uint256[])public betsByUser;
    mapping(address=>uint256)public amountMadeFromSoldBets;
    struct BetSale {
        address buyer;
        address previousOwner;
        uint256 amountPaid;
    }

    // Mapping to track all sales of a bet
    mapping(uint256 => BetSale[]) public soldBetHistory;
    
    



    
   


    
 
   
    
    event userCreatedABet();
    event BetUnlisted();
    event userBoughtBet();
    event userReListedBet();
    event winnerDeclaredVoting();
    event userVoted();
    event userWithdrew();
    event BetEdited();
    

    enum RaffleState {
        OPEN,
        VOTING,
        UNDERREVIEW,
        SETTLED
    }
     

    
 

    constructor(uint256 _endTime)  {
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
        require(msg.value>0);
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
        require(arrayOfBets[positionOfArray].owner != msg.sender, "You already own this bet");
        if(arrayOfBets[positionOfArray].amountBuyerLocked ==0){
            arrayOfBets[positionOfArray].amountBuyerLocked = msg.value;
        }else{
            soldBetHistory[positionOfArray].push(BetSale({
            buyer: msg.sender,
            previousOwner:arrayOfBets[positionOfArray].owner,
            amountPaid: msg.value
            }));
            amountMadeFromSoldBets[arrayOfBets[positionOfArray].owner] += msg.value;

        
             
        }
        betsByUser[msg.sender].push(positionOfArray);
        arrayOfBets[positionOfArray].owner = msg.sender;
        arrayOfBets[positionOfArray].selling = false;
        
        emit userBoughtBet();

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
    // Declare the mapping as a state variable
    mapping(address => uint256) private tempBalance;
    address[] private refundAddresses;

    function refundSoldBets() private onlyStaff {
      
        delete refundAddresses;

        // Iterate through each bet
       for (uint256 i = 0; i < arrayOfBets.length; i++) {
                if (soldBetHistory[i].length > 0) {
                    // Iterate through the history of sold bets for this bet
                    for (uint256 j = 0; j < soldBetHistory[i].length; j++) {
                        address buyer = soldBetHistory[i][j].buyer;
                        uint256 amountPaid = soldBetHistory[i][j].amountPaid;

                        // Check if the buyer is already in the addresses array
                        bool alreadyExists = false;
                        for (uint256 k = 0; k < refundAddresses.length; k++) {
                            if (refundAddresses[k] == buyer) {
                                alreadyExists = true;
                                break;
                            }
                        }

                        // Add buyer to addresses array if not already added
                        if (!alreadyExists) {
                            refundAddresses.push(buyer);
                        }

                        // Accumulate the amount paid in tempBalance
                        tempBalance[buyer] += amountPaid;

                        // If we're at the last entry, set the original owner
                        if (j == soldBetHistory[i].length - 1) {
                            arrayOfBets[i].owner = soldBetHistory[i][0].previousOwner;
                        }
                    }
                }
            }


        // Refund all addresses
        for (uint256 i = 0; i < refundAddresses.length; i++) {
            address buyer = refundAddresses[i];
            uint256 balanceToRefund = tempBalance[buyer];

            // Ensure there is a balance to refund
            if (balanceToRefund > 0) {
                payable(buyer).transfer(balanceToRefund);
                tempBalance[buyer] = 0;  // Reset balance after refund
            }
        }
    }


 


    
    

    function declareWinner(uint8 _winner)public onlyStaff nonReentrant{
        require((_winner>0) && (_winner < 4));
        if(_winner==3){
            refundSoldBets();
            s_raffleState = RaffleState.SETTLED;
            winner = 3;
            emit winnerDeclaredVoting();


        }
        else{
        if(s_raffleState == RaffleState.OPEN){
            uint256 currentTime = block.timestamp;
            endOfVoting = currentTime + 300;
            //endOfVoting = currentTime + 7200;
            s_raffleState = RaffleState.VOTING;
            winner = _winner;
            emit winnerDeclaredVoting();
           
        }
        else{
            require(
                (s_raffleState == RaffleState.VOTING && block.timestamp > endOfVoting) || s_raffleState == RaffleState.UNDERREVIEW,
                "Raffle state must be in VOTING and past end of voting, or in UNDERREVIEW state."
            );
            winner = _winner;
            emit winnerDeclaredVoting();
            s_raffleState = RaffleState.SETTLED;
        }   
    }}





    function disagreeWithOwner()public nonReentrant{
        require((s_raffleState == RaffleState.VOTING && block.timestamp < endOfVoting) || (s_raffleState == RaffleState.OPEN && block.timestamp > endTime), "Invalid state or time");
        s_raffleState = RaffleState.UNDERREVIEW;
        emit userVoted();

    }
    function allBets_Balance() 
    public 
    view 
    returns (
        bet[] memory, 
        uint256, 
        uint8, 
        RaffleState, 
        uint256, 
        uint256
    ) 
{
    uint256 betterBalanceNew = 0;
    uint256 creatorPay = 0;
    bool isWinnerThree = winner == 3;
    bool isWinnerZero = winner == 0;

    uint256[] storage userBets = betsByUser[msg.sender];
    uint256 userBetsLength = userBets.length;

    // Use a local mapping-like structure to track processed bets
    // Since mappings cannot be declared in memory, we'll use a temporary array
    uint256[] memory uniqueBets = new uint256[](userBetsLength);
    uint256 uniqueCount = 0;

    for (uint256 i = 0; i < userBetsLength; i++) {
        uint256 betIndex = userBets[i];
        bool isDuplicate = false;

        // Check if the betIndex has already been processed
        for (uint256 j = 0; j < uniqueCount; j++) {
            if (uniqueBets[j] == betIndex) {
                isDuplicate = true;
                break;
            }
        }

        if (!isDuplicate) {
            uniqueBets[uniqueCount] = betIndex;
            uniqueCount++;
        }
    }

    // Now process each unique bet
    for (uint256 i = 0; i < uniqueCount; i++) {
        uint256 betIndex = uniqueBets[i];
        bet storage currentBet = arrayOfBets[betIndex];

        if (!isWinnerZero) {
            if (isWinnerThree) {
                if (currentBet.owner == msg.sender) {
                    betterBalanceNew += currentBet.amountBuyerLocked;
                }
                if (currentBet.deployer == msg.sender) {
                    betterBalanceNew += currentBet.amountDeployerLocked;
                }
            } else {
                if (currentBet.deployer == msg.sender && currentBet.owner == msg.sender) {
                    betterBalanceNew += currentBet.amountDeployerLocked + currentBet.amountBuyerLocked;
                } else if (
                    (currentBet.owner == msg.sender && currentBet.conditionForBuyerToWin == winner) ||
                    (currentBet.deployer == msg.sender && currentBet.conditionForBuyerToWin != winner)
                ) {
                    betterBalanceNew += currentBet.amountBuyerLocked + currentBet.amountDeployerLocked;
                    if (currentBet.owner == msg.sender) {
                        creatorPay += currentBet.amountDeployerLocked;
                    } else {
                        creatorPay += currentBet.amountBuyerLocked;
                    }
                }
            }
        }
    }

    if (!isWinnerThree && creatorPay > 0) {
        uint256 creatorFee = (creatorPay * 5) / 100;
        betterBalanceNew -= creatorFee;
        betterBalanceNew += amountMadeFromSoldBets[msg.sender];
    }

    return (
        arrayOfBets, 
        endTime, 
        winner, 
        s_raffleState, 
        endOfVoting, 
        betterBalanceNew
    );
}




//     function allBets_Balance() 
//     public 
//     view 
//     returns (
//         bet[] memory, 
//         uint256, 
//         uint8, 
//         RaffleState, 
//         uint256, 
//         uint256
//     ) 
//     {
//     uint256 betterBalanceNew = 0;
   

//     uint256[] storage userBets = betsByUser[msg.sender]; // Direct access to save on gas

//     uint256 creatorPay = 0;
//     bool isWinnerThree = winner == 3;
//     bool isWinnerZero = winner == 0;

//     for (uint256 i = 0; i < userBets.length; i++) {
//         uint256 betIndex = userBets[i];
//         bet storage currentBet = arrayOfBets[betIndex];

//         if (!isWinnerZero) {
//             if (isWinnerThree) {
//                 if (currentBet.owner == msg.sender) {
//                     betterBalanceNew += currentBet.amountBuyerLocked;
//                 }
//                 if (currentBet.deployer == msg.sender) {
//                     betterBalanceNew += currentBet.amountDeployerLocked;
//                 }
//             } else {
//                 if (currentBet.deployer == msg.sender && currentBet.owner == msg.sender) {
//                     betterBalanceNew += (currentBet.amountDeployerLocked + currentBet.amountBuyerLocked);
//                 } else if (
//                     (currentBet.owner == msg.sender && currentBet.conditionForBuyerToWin == winner) ||
//                     (currentBet.deployer == msg.sender && currentBet.conditionForBuyerToWin != winner)
//                 ) {
//                     betterBalanceNew += currentBet.amountBuyerLocked + currentBet.amountDeployerLocked;
//                     if(currentBet.owner == msg.sender){
//                         creatorPay +=currentBet.amountDeployerLocked;
//                     }else{
//                         creatorPay +=currentBet.amountBuyerLocked;
//                     }
                    
//                 }
//             }
//         }
//     }

//     if (!isWinnerThree && creatorPay > 0) {
//         uint256 creatorFee = (creatorPay * 5) / 100;
//         betterBalanceNew -= creatorFee;
//         betterBalanceNew += amountMadeFromSoldBets[msg.sender];
//     }
    
   


//     // Ensure that `endTime`, `winner`, `s_raffleState`, and `endOfVoting` are properly defined in your contract
//     return (
//         arrayOfBets, 
//         endTime, 
//         winner, 
//         s_raffleState, 
//         endOfVoting, 
//         betterBalanceNew
//     );
// }



    

function withdraw() public nonReentrant {
    // Ensure the raffle is either SETTLED or in VOTING phase and voting has ended
    require(
        (s_raffleState == RaffleState.SETTLED) || 
        (s_raffleState == RaffleState.VOTING && block.timestamp > endOfVoting),
        "Cannot withdraw at this time"
    );

    // Check if the user has placed any bets
    uint256[] storage userBets = betsByUser[msg.sender];
    require(userBets.length > 0, "No bets found for user");

    uint256 betterBalanceNew = 0;
    uint256 creatorPay = 0;
    bool isWinnerThree = winner == 3;

    // Iterate through each bet of the user
    for (uint256 i = 0; i < userBets.length; i++) {
        uint256 betIndex = userBets[i];
        bet storage currentBet = arrayOfBets[betIndex];

        if (isWinnerThree) {
            // If winner is 3, clear locked amounts for the bet owner or deployer
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
                // If the same user is both owner and deployer, unlock both amounts
                betterBalanceNew += (currentBet.amountDeployerLocked + currentBet.amountBuyerLocked);
                currentBet.amountDeployerLocked = 0;
                currentBet.amountBuyerLocked = 0;
            } else if (
                (currentBet.owner == msg.sender && currentBet.conditionForBuyerToWin == winner) ||
                (currentBet.deployer == msg.sender && currentBet.conditionForBuyerToWin != winner)
            ) {
                // If either the owner or deployer wins, transfer the locked amounts
                uint256 totalLockedAmount = currentBet.amountBuyerLocked + currentBet.amountDeployerLocked;
                betterBalanceNew += totalLockedAmount;

                if (currentBet.owner == msg.sender && currentBet.conditionForBuyerToWin == winner) {
                    creatorPay += currentBet.amountDeployerLocked;
                } else {
                    creatorPay += currentBet.amountBuyerLocked;
                }

                currentBet.amountBuyerLocked = 0;
                currentBet.amountDeployerLocked = 0;
            }
        }
    }

    // Calculate creator fee and staff pay if applicable
    if (!isWinnerThree && creatorPay > 0) {
        uint256 _staffPay = (creatorPay * 300) / 10000; // 3% fee
        uint256 creatorFee = (creatorPay * 200) / 10000;  // 2% staff pay

        staffPay += _staffPay;
        creatorLocked += creatorFee;
        betterBalanceNew -= (creatorFee + _staffPay);
        betterBalanceNew += amountMadeFromSoldBets[msg.sender];
        amountMadeFromSoldBets[msg.sender] = 0;
    }

    // Ensure there is a balance to withdraw and the contract has enough funds
    require(betterBalanceNew > 0, "No balance to withdraw");
    require(address(this).balance >= betterBalanceNew, "Insufficient contract balance");

    // Transfer the balance to the user
    payable(msg.sender).transfer(betterBalanceNew);

    // Emit withdrawal event
    emit userWithdrew();
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
    bet storage currentBet = arrayOfBets[positionOfArray];
    require(
        currentBet.owner == msg.sender && 
        currentBet.deployer == msg.sender, 
        "Only the deployer who is also the owner can edit this bet"
    );

    uint currentLockedAmount = currentBet.amountDeployerLocked;

    if (newDeployPrice != currentLockedAmount) {
        if (newDeployPrice < currentLockedAmount) {
            // Refund excess funds if new deploy price is less
            uint refundAmount = currentLockedAmount - newDeployPrice;
            require(address(this).balance >= refundAmount, "Insufficient contract funds for refund");
            currentBet.amountDeployerLocked = newDeployPrice;
            payable(msg.sender).transfer(refundAmount);
        } else {
            // Ensure additional funds are sent if new deploy price is more
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

    emit BetEdited();
}



    function transferOwnerAmount()public onlyOwnerOrStaff nonReentrant{
        require(((s_raffleState == RaffleState.VOTING && block.timestamp > endOfVoting) ||  s_raffleState == RaffleState.SETTLED), "Invalid state or time");
        require(creatorLocked > 0);
        payable(owner).transfer(creatorLocked);
        creatorLocked = 0;

    }

    function transferStaffAmount()public onlyStaff nonReentrant{
        require(((s_raffleState == RaffleState.VOTING && block.timestamp > endOfVoting )|| s_raffleState == RaffleState.SETTLED), "Invalid state or time");
        require(staffPay > 0);
        payable(msg.sender).transfer(staffPay);
        staffPay = 0;
    }

    

}



