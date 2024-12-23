// SPDX-License-Identifier: MIT
// 1. Pragma
pragma solidity ^0.8.20;
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";


contract predMarket2 is ReentrancyGuard {

    address public immutable owner;
    bool private locked;

     // Rate limiting
 

     modifier noNesting() {
        require(!locked, "No nested calls");
        locked = true;
        _;
        locked = false;
    }

  



   


   
   uint96 public staffPay;
   mapping(address => bool) public staffWalletMap;

    modifier onlyStaff() {
        require(staffWalletMap[msg.sender], "Caller is not a staff member");
        _;
    }
    

   

    uint256 public endOfVoting;
    uint96 public creatorLocked;
    uint256 endTime;
    uint8 public winner;
    RaffleState public s_raffleState;
    mapping(address => uint32[])public betsByUser;
    mapping(address=>uint96)public amountMadeFromSoldBets;
    struct BetSale {
        address buyer;
        address previousOwner;
        uint96 amountPaid;
    }

    // Mapping to track all sales of a bet
    mapping(uint32 => BetSale[]) public soldBetHistory;
    event PayoutProcessed();
    event FundsRedistributed(address indexed beneficiary, uint amount);
    // Declare the mapping as a state variable
    mapping(address => uint96) private tempBalance;
    address[] private refundAddresses;
    
    
    




    
   


    
 
   
    
event userCreatedABet(uint32 positionInArray);

event BetUnlisted();
event userBoughtBet(uint32 position, address buyer, uint96 amount);
event userReListedBet();
event winnerDeclaredVoting();
event userVoted();
event userWithdrew(address user, uint96 amount);
event BetEdited();
event BetCancelled();
  
    

    enum RaffleState {
        OPEN,
        VOTING,
        UNDERREVIEW,
        SETTLED
    }
     

    
 

  constructor(uint256 _endTime) {
    require(msg.sender != address(0), "Invalid owner address");
    require(_endTime > block.timestamp, "Invalid end time");
    staffWalletMap[0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266] = true;
    owner = msg.sender;
    endTime = _endTime;
    s_raffleState = RaffleState.OPEN;
}

    modifier onlyOwnerOrStaff() {
    require(msg.sender == owner || staffWalletMap[msg.sender], "Caller is not the owner or a staff member");
    _;
}








   

struct bet {
        address deployer;
        address owner;
        uint96 amountDeployerLocked; // Reduced from uint256 to uint96 (still allows for large amounts)
        uint96 amountBuyerLocked;
        uint96 amountToBuyFor;
        uint8 conditionForBuyerToWin;
        bool selling;
        bool isActive;
        uint32 positionInArray; // Reduced from uint256 to uint32 (allows for 4 billion bets)
    }

    bet[] public arrayOfBets;

 // Safe receive function
    receive() external payable {
      
    }

    // Safe fallback
    fallback() external payable {
        revert();
    }

function sellANewBet(uint96 amountToBuy, uint8 conditionToWIn) 
    public 
    payable 
    nonReentrant
    noNesting 
     
     
{
    require(
        conditionToWIn > 0 && 
        conditionToWIn <= 2 &&
        s_raffleState == RaffleState.OPEN &&
        arrayOfBets.length < 300 &&
        amountToBuy > 0 &&
        betsByUser[msg.sender].length < 50
    );
    

    
    // Safe conversion to uint96
    require(msg.value <= type(uint96).max, "Amount too large");
    require(amountToBuy <= type(uint96).max, "Buy amount too large");
    
    
    
    uint32 positionInArray = uint32(arrayOfBets.length);
    betsByUser[msg.sender].push(positionInArray);
    
    arrayOfBets.push(bet({
        deployer: msg.sender,
        amountDeployerLocked: uint96(msg.value),
        owner: msg.sender,
        amountBuyerLocked: 0,
        amountToBuyFor: amountToBuy,
        conditionForBuyerToWin: conditionToWIn,
        selling: true,
        positionInArray: positionInArray,
        isActive: true
    }));
    emit userCreatedABet(positionInArray);
     

}

   function changeState(uint8 state) public onlyStaff {
        require(state <= uint8(RaffleState.SETTLED), "Invalid state value"); // Ensure valid state
        s_raffleState = RaffleState(state); // Cast uint8 to RaffleState enum
    }

    function unlistBets(uint32[] memory positionsOfArray) public nonReentrant noNesting 
     {
     
        // Loop through each position provided in the array
        require(positionsOfArray.length<=betsByUser[msg.sender].length + 5);
        for (uint32 i = 0; i < positionsOfArray.length;) {
            uint32 position = positionsOfArray[i];
            // Check if the sender is the owner of the bet
            require(arrayOfBets[position].owner == msg.sender, "Caller is not the owner");
            // Check if the bet is currently marked as selling
            require(arrayOfBets[position].selling == true, "Bet is not for sale");
            require(arrayOfBets[position].isActive);
            require(position<arrayOfBets.length,"Invalid Position");

            // Mark the bet as not selling
            arrayOfBets[position].selling = false;
            // Emit an event for the unlisted bet

            unchecked { ++i; }
            
        }
        emit BetUnlisted();
      
    }

 

function buyABet(uint32 positionOfArray) public payable nonReentrant noNesting   {
    require(s_raffleState == RaffleState.OPEN);
    bet storage currentBet = arrayOfBets[positionOfArray];
    
    require(
        currentBet.isActive &&
        uint96(msg.value) == currentBet.amountToBuyFor &&
        msg.value <= type(uint96).max &&
        currentBet.selling &&
        currentBet.owner != msg.sender &&
        positionOfArray < arrayOfBets.length
    );


    address previousOwner = currentBet.owner;
    
    if (currentBet.amountBuyerLocked == 0) {
        currentBet.amountBuyerLocked = uint96(msg.value);  // Explicit cast to uint96
    } else {
        unchecked {
            amountMadeFromSoldBets[previousOwner] += uint96(msg.value);  // This can stay uint256
        }
        soldBetHistory[positionOfArray].push(BetSale({
            buyer: msg.sender,
            previousOwner: previousOwner,
            amountPaid: uint96(msg.value)  // This can stay uint256 as it's part of BetSale struct
        }));
    }

    betsByUser[msg.sender].push(positionOfArray);
    currentBet.owner = msg.sender;
    currentBet.selling = false;
    
    emit userBoughtBet(positionOfArray, msg.sender, uint96(msg.value));
  
}


    


function sellAnExistingBet(uint32 positionOfArray, uint96 newAskingPrice) public nonReentrant noNesting  {
    require(s_raffleState == RaffleState.OPEN);
    require(positionOfArray < arrayOfBets.length);
    bet storage currentBet = arrayOfBets[positionOfArray];
    
    require(
        currentBet.owner == msg.sender &&
        currentBet.isActive &&
        newAskingPrice > 0 

    );
 
    
    currentBet.amountToBuyFor = newAskingPrice;
    currentBet.selling = true;
    
    emit userReListedBet();

  
}

  

   
function refundSoldBets() private {
    // Clear previous refund data
    delete refundAddresses;
    
    uint32 betsLength = uint32(arrayOfBets.length);
    for (uint32 i; i < betsLength;) {
        BetSale[] storage salesHistory = soldBetHistory[i];
        uint256 salesLength = salesHistory.length;
        
        if (salesLength > 0) {
            // Process each sale in history
            for (uint256 j; j < salesLength;) {
                address buyer = salesHistory[j].buyer;
                
                unchecked {
                    tempBalance[buyer] += salesHistory[j].amountPaid;
                }
                
                // Add unique addresses
                if (tempBalance[buyer] > 0 && !_addressExists(buyer)) {
                    refundAddresses.push(buyer);
                }
             
                
                unchecked { ++j; }
            }
            arrayOfBets[i].owner = salesHistory[0].previousOwner;
        

            // amountMadeFromSoldBets[salesHistory[0].previousOwner] = 0


        }
        unchecked { ++i; }
    }

    // Process refunds
    uint256 refundLength = refundAddresses.length;
    for (uint256 i; i < refundLength;) {
        address payable buyer = payable(refundAddresses[i]);
        uint96 refundAmount = tempBalance[buyer];
        
        if (refundAmount > 0) {
            tempBalance[buyer] = 0;  // Reset before transfer to prevent reentrancy
            (bool success, ) = buyer.call{value: refundAmount}("");
            require(success, "Refund failed");
            // amountMadeFromSoldBets[buyer] = 0;
            // amountMadeFromSoldBets[buyer] += refundAmount;

        }
        
        unchecked { ++i; }
    }
}

// New helper function to check if address exists in refundAddresses
function _addressExists(address addr) private view returns (bool) {
    uint256 length = refundAddresses.length;
    for (uint256 i; i < length;) {
        if (refundAddresses[i] == addr) {
            return true;
        }
        unchecked { ++i; }
    }
    return false;
}



 


    
    
function declareWinner(uint8 _winner) public onlyStaff nonReentrant {
    require(_winner > 0 && _winner < 4);
    
    if (_winner == 3) {
        refundSoldBets();
        s_raffleState = RaffleState.SETTLED;
        winner = 3;
        emit winnerDeclaredVoting();
        return;
    }
    
    if (s_raffleState == RaffleState.OPEN) {
        unchecked {
            endOfVoting = block.timestamp + 300; // +300 for 5 minutes
        }
        s_raffleState = RaffleState.VOTING;
        winner = _winner;
        emit winnerDeclaredVoting();
    } else {
        require(
            (s_raffleState == RaffleState.VOTING && block.timestamp > endOfVoting) || 
            s_raffleState == RaffleState.UNDERREVIEW
        );
        winner = _winner;
        s_raffleState = RaffleState.SETTLED;
        emit winnerDeclaredVoting();
    }
}




function disagreeWithOwner() public nonReentrant noNesting {
    require(
        (s_raffleState == RaffleState.VOTING && block.timestamp < endOfVoting) || 
        (s_raffleState == RaffleState.OPEN && block.timestamp > endTime)
    );
   
    s_raffleState = RaffleState.UNDERREVIEW;
    emit userVoted();
    
}

function allBets_Balance() public view returns (
    bet[] memory activeBets, 
    uint256 endTimeValue, 
    uint8 winnerValue, 
    RaffleState state, 
    uint256 votingEnd, 
    uint96 balance
) {
    uint32[] storage userBets = betsByUser[msg.sender];
    uint256 userBetsLength = userBets.length;
    
    // Get unique bets and calculate balances
    (uint96 betterBalanceNew, uint96 creatorPay) = _calculateBalances(userBets, userBetsLength);

    // Apply fees and add sold bets balance if not winner three
    if (winner != 3) {
        unchecked {
            uint96 creatorFee = (creatorPay * 5) / 100;
            betterBalanceNew = betterBalanceNew - creatorFee + amountMadeFromSoldBets[msg.sender];
        }
    }else if(winner == 3){
        // betterBalanceNew = betterBalanceNew + amountMadeFromSoldBets[msg.sender];
         betterBalanceNew = betterBalanceNew;
    }

    // Get active bets efficiently
    activeBets = _getActiveBets();

    return (
        activeBets,
        endTime,
        winner,
        s_raffleState,
        endOfVoting,
        betterBalanceNew
    );
}

function _calculateBalances(uint32[] storage userBets, uint256 length) private view returns (uint96 balance, uint96 creatorPay) {
    // Use a fixed-size array instead of mapping for processed bets
    uint256[] memory processed = new uint256[](length);
    uint256 processedCount;
    
    for (uint256 i; i < length;) {
        uint256 betIndex = uint256(userBets[i]);
        bool isDuplicate = false;
        
        // Check if bet was already processed
        for (uint256 j; j < processedCount;) {
            if (processed[j] == betIndex) {
                isDuplicate = true;
                break;
            }
            unchecked { ++j; }
        }
        
        if (!isDuplicate) {
            processed[processedCount] = betIndex;
            unchecked { ++processedCount; }
            
            bet storage currentBet = arrayOfBets[betIndex];
            (uint96 betBalance, uint96 betCreatorPay) = _calculateSingleBetBalance(currentBet);
            
            unchecked {
                balance += betBalance;
                creatorPay += betCreatorPay;
            }
        }
        
        unchecked { ++i; }
    }
}
// New helper for single bet balance calculation
function _calculateSingleBetBalance(bet storage currentBet) private view returns (uint96 balance, uint96 creatorPay) {
    if (winner == 0) return (0, 0);
    
    if (winner == 3) {
        if (currentBet.owner == msg.sender) {
            balance = currentBet.amountBuyerLocked;
        }
        if (currentBet.deployer == msg.sender) {
            balance += currentBet.amountDeployerLocked;
        }
        return (balance, 0);
    }

    if (currentBet.deployer == msg.sender && currentBet.owner == msg.sender) {
        return (currentBet.amountDeployerLocked + currentBet.amountBuyerLocked, 0);
    }

    bool isWinner = (currentBet.owner == msg.sender && currentBet.conditionForBuyerToWin == winner) ||
                   (currentBet.deployer == msg.sender && currentBet.conditionForBuyerToWin != winner);

    if (isWinner) {
        balance = currentBet.amountBuyerLocked + currentBet.amountDeployerLocked;
        creatorPay = currentBet.owner == msg.sender ? 
            currentBet.amountDeployerLocked : 
            currentBet.amountBuyerLocked;
    }
}

// Optimize active bets retrieval
function _getActiveBets() private view returns (bet[] memory) {
    uint256 totalBets = arrayOfBets.length;
    uint256 activeCount;
    
    // Single pass implementation
    bet[] memory tempBets = new bet[](totalBets);
    for (uint256 i; i < totalBets;) {
        if (arrayOfBets[i].isActive) {
            tempBets[activeCount] = arrayOfBets[i];
            unchecked { ++activeCount; }
        }
        unchecked { ++i; }
    }

    // Create right-sized array
    bet[] memory activeBets = new bet[](activeCount);
    for (uint256 i; i < activeCount;) {
        activeBets[i] = tempBets[i];
        unchecked { ++i; }
    }
    
    return activeBets;
}





    function withdraw() public nonReentrant noNesting 
         {
    require(
        s_raffleState == RaffleState.SETTLED || 
        (s_raffleState == RaffleState.VOTING && block.timestamp > endOfVoting)
    );

    uint32[] storage userBets = betsByUser[msg.sender];
    require(userBets.length > 0);
   

    uint96 betterBalanceNew;
    uint96 creatorPay;
    bool isWinnerThree = winner == 3;

    uint32 length = uint32(userBets.length);
    for (uint32 i; i < length;) {
        bet storage currentBet = arrayOfBets[userBets[i]];
        
        if (isWinnerThree) {
            if (currentBet.owner == msg.sender) {
                unchecked {
                    betterBalanceNew += currentBet.amountBuyerLocked;
                }
                currentBet.amountBuyerLocked = 0;
            }
            if (currentBet.deployer == msg.sender) {
                unchecked {
                    betterBalanceNew += currentBet.amountDeployerLocked;
                }
                currentBet.amountDeployerLocked = 0;
            }
        } else {
            (uint96 balance, uint96 creator) = _calculateWinnings(currentBet);
            unchecked {
                betterBalanceNew += balance;
                creatorPay += creator;
            }
        }
        
        unchecked { ++i; }
    }

    if (!isWinnerThree) {
        unchecked {
            
            uint96 fees = (creatorPay * 500) / 10000; // Combined 5% fee
            require(betterBalanceNew >= fees, "Insufficient balance for fees");
            betterBalanceNew -= fees;
            staffPay += (fees * 3) / 5;    // 3% to staff
            creatorLocked += (fees * 2) / 5; // 2% to creator
        }
    }

  
    if (amountMadeFromSoldBets[msg.sender] > 0 && !isWinnerThree ) {
        unchecked {
            betterBalanceNew += amountMadeFromSoldBets[msg.sender];
        }
        amountMadeFromSoldBets[msg.sender] = 0;
    }

    require(betterBalanceNew > 0 && address(this).balance >= betterBalanceNew,"Not enough Shmeckles in Contract");
    
    // Transfer balance
    (bool success, ) = payable(msg.sender).call{value: betterBalanceNew}("");
    require(success, "Transfer failed");

    emit userWithdrew(msg.sender, betterBalanceNew);
  
}

function _calculateWinnings(bet storage currentBet) private  returns (uint96 balance, uint96 creator) {
    if (currentBet.deployer == msg.sender && currentBet.owner == msg.sender) {
        balance = currentBet.amountDeployerLocked + currentBet.amountBuyerLocked;
        currentBet.amountDeployerLocked = 0;
        currentBet.amountBuyerLocked = 0;
    } else if (
        (currentBet.owner == msg.sender && currentBet.conditionForBuyerToWin == winner) ||
        (currentBet.deployer == msg.sender && currentBet.conditionForBuyerToWin != winner)
    ) {
        balance = currentBet.amountBuyerLocked + currentBet.amountDeployerLocked;
        creator = currentBet.owner == msg.sender ? currentBet.amountDeployerLocked : currentBet.amountBuyerLocked;
        currentBet.amountBuyerLocked = 0;
        currentBet.amountDeployerLocked = 0;
    }
}



function cancelOwnedBet(uint32 positionOfArray) public nonReentrant {
    require(positionOfArray<arrayOfBets.length);
    bet storage currentBet = arrayOfBets[positionOfArray];
    
    require(
        currentBet.owner == msg.sender && 
        currentBet.deployer == msg.sender &&
        currentBet.isActive,
        "Not authorized or bet inactive"
    );
    
    
    uint96 refundAmount;
    unchecked {
        refundAmount = currentBet.amountBuyerLocked + currentBet.amountDeployerLocked;
    }
    
    // Clear bet data before transfer
    currentBet.owner = address(0);
    currentBet.deployer = address(0);
    currentBet.amountBuyerLocked = 0;
    currentBet.amountDeployerLocked = 0;
    currentBet.isActive = false;
    
    // Transfer refund
    (bool success, ) = payable(msg.sender).call{value: refundAmount}("");
    require(success, "Transfer failed");
    
    emit BetCancelled();
}




function editADeployedBet(
    uint32 positionOfArray, 
    uint96 newDeployPrice, 
    uint96 newAskingPrice
) public payable nonReentrant noNesting 
         {
    require(positionOfArray < arrayOfBets.length, "Invalid position");
    
    bet storage currentBet = arrayOfBets[positionOfArray];
    require(
        currentBet.owner == msg.sender && 
        currentBet.deployer == msg.sender && 
        newDeployPrice >=0 &&
        newAskingPrice >=0 &&
        currentBet.isActive &&
        s_raffleState == RaffleState.OPEN,
        "Not authorized or bet inactive"
    );
    
    
    uint96 currentLocked = currentBet.amountDeployerLocked;
    
    if (newDeployPrice != currentLocked) {
        if (newDeployPrice < currentLocked) {
            uint96 refundAmount;
            unchecked {
                refundAmount = currentLocked - newDeployPrice;
            }
            currentBet.amountDeployerLocked = newDeployPrice;
            (bool success, ) = payable(msg.sender).call{value: refundAmount}("");
            require(success, "Refund failed");
        } else {
            uint96 additionalAmount;
            unchecked {
                additionalAmount = newDeployPrice - currentLocked;
            }
            require(msg.value == additionalAmount, "Incorrect value sent");
            currentBet.amountDeployerLocked = newDeployPrice;
        }
    }
    
    currentBet.amountToBuyFor = newAskingPrice;
    currentBet.selling = true;
    
    emit BetEdited();
  
}



function transferOwnerAmount() public onlyOwnerOrStaff nonReentrant noNesting 
          {
    require(
        (s_raffleState == RaffleState.VOTING && block.timestamp > endOfVoting) || 
        s_raffleState == RaffleState.SETTLED
    );
    require(creatorLocked > 0);
    
    uint96 amount = creatorLocked;
    creatorLocked = 0; // Reset before transfer to prevent reentrancy
    
    (bool success, ) = payable(owner).call{value: amount}("");
    require(success, "Transfer failed");
}

// Optimize transferStaffAmount
function transferStaffAmount() public onlyStaff nonReentrant {
    require(
        (s_raffleState == RaffleState.VOTING && block.timestamp > endOfVoting) || 
        s_raffleState == RaffleState.SETTLED
    );
    require(staffPay > 0);
    
    uint96 amount = staffPay;
    staffPay = 0; // Reset before transfer to prevent reentrancy
    
    (bool success, ) = payable(msg.sender).call{value: amount}("");
    require(success, "Transfer failed");
}

    

}



