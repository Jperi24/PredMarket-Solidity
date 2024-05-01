// SPDX-License-Identifier: MIT
// 1. Pragma
pragma solidity ^0.8.20;
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";


contract predMarket2 is ReentrancyGuard {

    address private immutable owner;
    address private immutable staffWallet = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
   

   

    uint256 public endOfVoting;
    uint8 public winner;
    RaffleState private s_raffleState;
    uint256 endTime;



    mapping(address => uint256)public betterBalance;
   



    event contractDeployed(uint256 timeStamp);
    event winnerDeclaredVoting(uint8 winnerIs);
    event winnerFinalized(uint8 winnerIs);
    event userPlacedBet(address indexed sender, uint256 betPlacedValue);
    event userReducedBet(address indexed sender, uint256 betReduced);
    event userWithdrewBet(address indexed sender,string betAorB);
    event underReview();
    event newBetOffered();
    event shithappened();
    event BetUnlisted(uint indexed positionOfArray);

    enum RaffleState {
        OPEN,
        VOTING,
        UNDERREVIEW,
        SETTLED,
        PAYOUT
    }
     

    
 

    constructor(uint256 _endTime) payable {
        require(msg.value == 50000000000000000, "Deployment requires exactly 0.05 Ether");
        owner = msg.sender;
        endTime = _endTime;
        s_raffleState = RaffleState.OPEN;
        



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
        uint256 amountBuyerLocked;
        uint256 amountToBuyFor;
        uint8 conditionForBuyerToWin;//0 a wins, 1 b wins, 2 draw
        bool selling;
        uint256 positionInArray;
    
        
    }

     bet[] public arrayOfBets;

    function sellANewBet(uint256 amountToBuy,uint8 conditionToWIn ) public payable{
        require(conditionToWIn > 0 && conditionToWIn <= 2);
        require(s_raffleState == RaffleState.OPEN);

        bet memory newBet = bet(msg.sender,msg.value, msg.sender,0,amountToBuy, conditionToWIn,true,arrayOfBets.length);
        arrayOfBets.push(newBet);
        emit shithappened();
    }

    function unlistBets(uint[] memory positionsOfArray) public {
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

 

    // function listBet(uint positionOfArray)public{
    //     require(arrayOfBets[positionOfArray].owner == msg.sender);
    //     require(arrayOfBets[positionOfArray].selling == false);
    //     arrayOfBets[positionOfArray].selling = true;
    //     emit shithappened();
    // }

    function buyABet(uint positionOfArray) public payable{
        require(s_raffleState == RaffleState.OPEN);
        require(msg.value == arrayOfBets[positionOfArray].amountToBuyFor);
        require(arrayOfBets[positionOfArray].selling == true);
        if(arrayOfBets[positionOfArray].amountBuyerLocked ==0){
            arrayOfBets[positionOfArray].amountBuyerLocked += msg.value;
        }else{
            betterBalance[arrayOfBets[positionOfArray].owner] += msg.value;
        }
        arrayOfBets[positionOfArray].owner = msg.sender;
        arrayOfBets[positionOfArray].selling = false;
        emit shithappened();

    }

    function sellAnExistingBet(uint positionOfArray, uint newAskingPrice)public{
        require(s_raffleState == RaffleState.OPEN);
        require(arrayOfBets[positionOfArray].owner == msg.sender);
        arrayOfBets[positionOfArray].amountToBuyFor = newAskingPrice;
        arrayOfBets[positionOfArray].selling = true;
        emit shithappened();
    }

    // function redeemBets()public onlyOwner{
    //     require((s_raffleState == RaffleState.VOTING) && (block.timestamp> endOfVoting));

    //     uint i = 0;
    //     while(i<arrayOfBets.length){
    //         if(arrayOfBets[i].conditionForBuyerToWin == winner){
    //             //if the current owner wins the bet
    //             betterBalance[arrayOfBets[i].owner] += 
    //             (arrayOfBets[i].amountDeployerLocked + arrayOfBets[i].amountBuyerLocked);
    //             i++;
    //         }
    //         else if (arrayOfBets[i].conditionForBuyerToWin == (winner + 1)){
    //             betterBalance[arrayOfBets[i].deployer] += 
    //             (arrayOfBets[i].amountDeployerLocked + arrayOfBets[i].amountBuyerLocked);
    //             i++;
    //         }else{
    //             betterBalance[arrayOfBets[i].deployer] += arrayOfBets[i].amountDeployerLocked;
    //             betterBalance[arrayOfBets[i].owner] += arrayOfBets[i].amountBuyerLocked;


    //         }
    //     }
    //     emit shithappened();
    //     s_raffleState = RaffleState.PAYOUT;

    // }

    event PayoutProcessed();
    event FundsRedistributed(address indexed beneficiary, uint amount);

    function redeemBets() public onlyOwner {
        // Ensure that the raffle is in the VOTING state and the current time is past the end of voting
        require(s_raffleState == RaffleState.VOTING && block.timestamp > endOfVoting, "Redemption is not allowed at this time.");

        for (uint i = 0; i < arrayOfBets.length; i++) {
            uint totalAmount = arrayOfBets[i].amountDeployerLocked + arrayOfBets[i].amountBuyerLocked;

            if (arrayOfBets[i].conditionForBuyerToWin == winner) {
                // If the bet's condition matches the winner, the owner wins the total locked amount
                betterBalance[arrayOfBets[i].owner] += totalAmount;
                emit FundsRedistributed(arrayOfBets[i].owner, totalAmount);
            } else if (arrayOfBets[i].conditionForBuyerToWin == winner + 1) {
                // If the condition is one more than the winner, the deployer wins the total locked amount
                betterBalance[arrayOfBets[i].deployer] += totalAmount;
                emit FundsRedistributed(arrayOfBets[i].deployer, totalAmount);
            } else {
                // Otherwise, redistribute the locked amounts back to the deployer and owner respectively
                betterBalance[arrayOfBets[i].deployer] += arrayOfBets[i].amountDeployerLocked;
                betterBalance[arrayOfBets[i].owner] += arrayOfBets[i].amountBuyerLocked;
                emit FundsRedistributed(arrayOfBets[i].deployer, arrayOfBets[i].amountDeployerLocked);
                emit FundsRedistributed(arrayOfBets[i].owner, arrayOfBets[i].amountBuyerLocked);
            }
        }

        // Change the state to PAYOUT and emit the appropriate event
        s_raffleState = RaffleState.PAYOUT;
        emit PayoutProcessed();
    }

    function declareWinner(uint8 _winner)public onlyOwner{
        require(s_raffleState == RaffleState.OPEN);
        endOfVoting = block.timestamp + 7200;
        s_raffleState = RaffleState.VOTING;
        winner = _winner;
        emit winnerDeclaredVoting(_winner);
        s_raffleState = RaffleState.VOTING;
    }

    function disagreeWithOwner()public payable{
        require(s_raffleState == RaffleState.VOTING || (block.timestamp > (endTime)));
        s_raffleState = RaffleState.UNDERREVIEW;
    }

    function allBets_Balance() public view returns(bet[] memory,uint256,uint256,uint8,RaffleState){
        uint256 balance = betterBalance[msg.sender];
        return (arrayOfBets,balance,endTime,winner,s_raffleState);
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



