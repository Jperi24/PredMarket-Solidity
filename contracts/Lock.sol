// SPDX-License-Identifier: MIT
// 1. Pragma
pragma solidity ^0.8.20;
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";


contract predMarket is ReentrancyGuard {

    address private immutable owner;
    address private immutable staffWallet = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
    uint256 public locked = 0;

    uint256 public BetA =0;
    uint256 public BetB = 0;
    RaffleState private s_raffleState;
    uint256 public endTime;
    uint256 public startTime;
    uint256 public voteTime;
    uint8 public winner;
    uint8 public disagree;
    uint256 buyIn;
    mapping(address=>bool) public boughtIn;
    uint256[2] public oddsBetA;
    uint256[2] public oddsBetB;
    error didNotBet(string betAorB);
    address public disagreeUser;

    event userBoughtIn(address indexed sender);
    event contractDeployed(uint256 timeStamp);
    event winnerDeclaredVoting(uint8 winnerIs, uint256 votingTime);
    event winnerFinalized(uint8 winnerIs);
    event userPlacedBet(address indexed sender, uint256 betPlacedValue);
    event userReducedBet(address indexed sender, uint256 betReduced);
    event userWithdrewBet(address indexed sender,string betAorB);
    event underReview();
    

     

    struct better {
        address payable bettor;
        uint256 amount;
        uint256[2] odds;
    }
    better[] public arrayOfBettersA;
    better[] public arrayOfBettersB;

    constructor(uint256 timeToEnd, uint256 _odds1, uint256 _odds2,uint256 _buyIn) payable {
        require(msg.value == 50000000000000000, "Deployment requires exactly 0.05 Ether");
        locked += msg.value;
        s_raffleState = RaffleState.OPEN;
        startTime = block.timestamp;
        endTime = startTime +timeToEnd;
        owner = msg.sender;
        oddsBetA[0] = _odds1;
        oddsBetA[1] = _odds2;
        oddsBetB[0] = _odds2;
        oddsBetB[1] = _odds1;
        buyIn = _buyIn;
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



     enum RaffleState {
        OPEN,
        VOTING,
        UNDERREVIEW,
        SETTLED,
        PAYOUT
    }

    function viewPots()public view returns(uint256,uint256){
        return (BetA,BetB);
    }




    function emptyLosingArray(better[] storage arrLost, better[] storage arrWinner)private {
        //Responsible for paying the winner and dedudcting from the losers in the correct order
        uint i = 0;
        while(i<arrWinner.length){
            if(arrWinner[i].bettor == payable(address(0))){
                i++;
            }
            uint x = 0;
            uint winnerNeeds = (arrWinner[i].amount * arrWinner[i].odds[0])/arrWinner[i].odds[1] ;
            while (x < arrLost.length) {
                if (arrLost[x].amount <= 0) {
                    x++; // Move to the next element if the current element is 0
                } else if (arrLost[x].amount > winnerNeeds) {
                    arrLost[x].amount -= winnerNeeds;
                    arrWinner[i].amount += winnerNeeds;
                    break;
                     // Winner keeps original value and receives additional amount based on the odds
                    // Removed console.log as it's not supported in Solidity
                    // break; // Break is not necessary as return already exits the function
                } else {
                    winnerNeeds -= arrLost[x].amount;
                    arrWinner[i].amount += arrLost[x].amount;
                    arrLost[x].amount = 0; // Set the current element to 0
                    x++; // Move to the next element
                }
            }
            i++;
        
    }
   }


    function winLossBetA(uint256 potentialBet,bool addition) public view returns(uint256,uint256, uint256,uint256,uint256,uint256) {
        bool bettorExists = false;
        uint256 potB = BetB; // Assuming BetB is declared somewhere in your contract
        uint256 potBStatic = BetB;
        uint betterPosition;
        better[] memory arrWinner;

        // Check if bettor exists
        for (uint i = 0; i < arrayOfBettersA.length; i++) {
            if (msg.sender == arrayOfBettersA[i].bettor) {
                bettorExists = true;
                betterPosition = i;
                break;
            }
        }

        // Create arrWinner
        if (!bettorExists) {
            if(addition){
                arrWinner = new better[](arrayOfBettersA.length + 1);
                for (uint i = 0; i < arrayOfBettersA.length; i++) {
                    arrWinner[i] = arrayOfBettersA[i];
                }
                arrWinner[arrayOfBettersA.length] = better(payable(msg.sender), potentialBet, oddsBetA);
                betterPosition = arrayOfBettersA.length;
            }else{
                return(0,0,0,0,potBStatic,arrayOfBettersA.length);
            }
        } else {

            if(addition){
                arrWinner = arrayOfBettersA;
                arrWinner[betterPosition].amount += potentialBet;
            // Note: This does not actually modify the array; it's for calculation purposes
            }else{
                if(arrayOfBettersA[betterPosition].amount >= potentialBet){
                    arrWinner = arrayOfBettersA;
                    arrWinner[betterPosition].amount -= potentialBet;
                }else{
                    return (0,0,0,0,potBStatic,arrayOfBettersA.length);
                }
                
            }
        }
           
                
        

        // Calculate winnings and risks
        uint256 payout;
        uint256 risk;
        uint256 payout2;
        for (uint i = 0; i < arrWinner.length; i++) {
            if(arrWinner[i].bettor == payable(address(0))){
                i++;
            }
            payout = (arrWinner[i].amount * oddsBetA[0]) / oddsBetA[1];
            payout2 = payout;
            if (i == betterPosition) {
                if (potB < payout) {
                    return (payout2, potB, (potB * oddsBetA[1]) / oddsBetA[0],arrWinner[i].amount,potBStatic,arrayOfBettersA.length);
                } else {
                    risk = (payout * oddsBetA[1]) / oddsBetA[0];
                    return (payout2, payout, arrWinner[i].amount,arrWinner[i].amount,potBStatic,arrayOfBettersA.length);
                }
            } else {
                if (potB >= payout) {
                    potB -= payout;
                }else{
                    potB = 0;
                }
            }
        }
        return (payout2,0, 0,arrWinner[betterPosition].amount,potBStatic,arrayOfBettersA.length); // Return default values if no condition is met
    }

    function winLossBetB(uint256 potentialBet,bool addition) public view returns(uint256, uint256, uint256, uint256,uint256,uint256) {
        bool bettorExists = false;
        uint256 potA = BetA;
        uint256 potAStatic = BetA; // Assuming BetA is declared somewhere in your contract
        uint betterPosition;
        better[] memory arrWinner;

        // Check if bettor exists
        for (uint i = 0; i < arrayOfBettersB.length; i++) {
            if (msg.sender == arrayOfBettersB[i].bettor) {
                bettorExists = true;
                betterPosition = i;
                break;
            }
        }

        // Create arrWinner
        if (!bettorExists) {
            if(addition){
                arrWinner = new better[](arrayOfBettersB.length + 1);
                for (uint i = 0; i < arrayOfBettersB.length; i++) {
                    arrWinner[i] = arrayOfBettersB[i];
                }
                arrWinner[arrayOfBettersB.length] = better(payable(msg.sender), potentialBet, oddsBetB);
                betterPosition = arrayOfBettersB.length;
            }else{
                return (0,0,0,0,potAStatic,arrayOfBettersB.length);
            }
        } else {
            if(addition){
                arrWinner = arrayOfBettersB;
                arrWinner[betterPosition].amount += potentialBet;
            // Note: This does not actually modify the array; it's for calculation purposes
            }else{
                if(arrayOfBettersB[betterPosition].amount >= potentialBet){
                    arrWinner = arrayOfBettersB;
                    arrWinner[betterPosition].amount -= potentialBet;
                }else{
                    return (0,0,0,0,potAStatic,arrayOfBettersB.length);
                }
                
            }
        }

        // Calculate winnings and risks
        uint256 payout;
        uint256 risk;
        uint256 payout2;
        for (uint i = 0; i < arrWinner.length; i++) {
            if(arrWinner[i].bettor == payable(address(0))){
                i++;
            }
            payout = (arrWinner[i].amount * oddsBetB[0]) / oddsBetB[1];
            payout2 = payout;
            if (i == betterPosition) {
                if (potA < payout) {
                    return (payout2, potA, (potA * oddsBetB[1]) / oddsBetB[0],arrWinner[betterPosition].amount,potAStatic,arrayOfBettersB.length);
                } else {
                    risk = (payout * oddsBetB[1]) / oddsBetB[0];
                    return (payout2 ,payout, arrWinner[i].amount,arrWinner[betterPosition].amount,potAStatic,arrayOfBettersB.length);
                }
            } else {
                if (potA >= payout) {
                    potA -= payout;
                }else{
                    potA = 0;
                }
            }
        }
        return (payout2, 0, 0,arrWinner[betterPosition].amount,potAStatic,arrayOfBettersB.length); // Return default values if no condition is met
    }




   function getBalance() public view returns (uint) {
        return address(this).balance;
    }


    function assignEveryoneAmount() public ownerOrStaff{
        require((s_raffleState== RaffleState.VOTING && block.timestamp >= voteTime) || (s_raffleState == RaffleState.SETTLED));
        if(s_raffleState ==RaffleState.SETTLED){
            require(msg.sender== staffWallet);
        }
        if(winner==0){
            emptyLosingArray(arrayOfBettersA,arrayOfBettersB);
            s_raffleState = RaffleState.PAYOUT;

        }
        else if(winner==1){
            emptyLosingArray(arrayOfBettersB,arrayOfBettersA);
            s_raffleState = RaffleState.PAYOUT;
        }
        else{
            s_raffleState = RaffleState.PAYOUT;

        }
        if(msg.sender == owner){
            payable(owner).transfer(locked);
        }

    }


  

    function payBuyIn() public payable {
        // Check that the user hasn't bought in yet
        require(!boughtIn[msg.sender], "User already bought in");
        require(block.timestamp <endTime);

        // Check that the exact buy-in amount is sent
        require(msg.value == buyIn, "Incorrect buy-in amount");

        // Mark the user as having bought in
        boughtIn[msg.sender] = true;

        // Transfer the buy-in funds to the owner
        locked += msg.value;
        emit userBoughtIn(msg.sender);
    }
    function betOnBetA() public payable returns(uint){
        require(s_raffleState== RaffleState.OPEN);
        require(boughtIn[msg.sender], "Must buy in before betting");
        require(block.timestamp <endTime);
        uint i = 0;
        while(i<arrayOfBettersA.length){
            if(arrayOfBettersA[i].bettor == msg.sender){
                arrayOfBettersA[i].amount+= msg.value;
                BetA += msg.value;
                return 0;
            }else{
                i++;
            }
        }
        better memory newbetter = better(payable(msg.sender),msg.value,oddsBetA);
        BetA += msg.value;
        //If s_bettersOnA does not contain msg.sender then += msg.sender
        arrayOfBettersA.push(newbetter);
        emit userPlacedBet(msg.sender,msg.value);
        return 0;
    }

    function betOnBetB() public payable returns(uint){
        require(s_raffleState== RaffleState.OPEN);
        require(block.timestamp <endTime);
        require(boughtIn[msg.sender], "Must buy in before betting");
        uint i = 0;
        while(i<arrayOfBettersB.length){
            if(arrayOfBettersB[i].bettor == msg.sender){
                arrayOfBettersB[i].amount+= msg.value;
                BetB += msg.value;
                return 0;
            }else{
                i++;
            }
        }
        better memory newbetter = better(payable(msg.sender),msg.value,oddsBetB);
        BetB += msg.value;
        //If s_bettersOnA does not contain msg.sender then += msg.sender
        arrayOfBettersB.push(newbetter);
        emit userPlacedBet(msg.sender,msg.value);
        return 0;
    }

    function reduceBetA(uint256 reduction)public nonReentrant{
        require(s_raffleState== RaffleState.OPEN);
        require(block.timestamp <endTime);
        uint i = 0;
        while(i<arrayOfBettersA.length){
            if(arrayOfBettersA[i].bettor==msg.sender){
                if(arrayOfBettersA[i].amount>= reduction){
                    arrayOfBettersA[i].amount -= reduction;
                    BetA -= reduction;
                    
                    // (bool success, ) = arrayOfBettersA[i].bettor.call{value: reduction}("");
                    // require(success, "Transfer failed");
                    arrayOfBettersA[i].bettor.transfer(reduction);
                   
                    emit userReducedBet(msg.sender,reduction);
                    break;
                }
            }
            else{
                i++;
            }
        }
    }
    function reduceBetB(uint256 reduction)public nonReentrant {
        require(s_raffleState== RaffleState.OPEN);
        require(block.timestamp <endTime);
        uint i = 0;
        while(i<arrayOfBettersB.length){
            if(arrayOfBettersB[i].bettor==msg.sender){
                if(arrayOfBettersB[i].amount>= reduction){
                    arrayOfBettersB[i].amount -= reduction;
                    BetB -= reduction;
                    // (bool success, ) = arrayOfBettersB[i].bettor.call{value: reduction}("");
                    // require(success, "Transfer failed");
                    arrayOfBettersB[i].bettor.transfer(reduction);
                    
                    emit userReducedBet(msg.sender,reduction);
                    break;
                }
            }
            else{
                i++;
            }
        }
    }

  

    function withdraw() public nonReentrant {
        require( s_raffleState == RaffleState.PAYOUT, "Raffle not in correct state for withdrawal");

        bool withdrawnA = false;
        bool withdrawnB = false;

        // Withdraw from A
        for (uint i = 0; i < arrayOfBettersA.length; i++) {
            if (arrayOfBettersA[i].bettor == msg.sender && arrayOfBettersA[i].amount > 0) {
                BetA -= arrayOfBettersA[i].amount;
                // (bool successA, ) = arrayOfBettersA[i].bettor.call{value: arrayOfBettersA[i].amount}("");
                // require(successA, "Transfer from A failed");
                arrayOfBettersA[i].bettor = payable(address(0));
                emit userWithdrewBet(msg.sender, "A");
                withdrawnA = true;
                arrayOfBettersA[i].bettor.transfer(arrayOfBettersA[i].amount);
                break; // Assuming a user can only be once in the array
            }
        }

        // Withdraw from B
        for (uint i = 0; i < arrayOfBettersB.length; i++) {
            if (arrayOfBettersB[i].bettor == msg.sender && arrayOfBettersB[i].amount > 0) {
                BetB -= arrayOfBettersB[i].amount;//this doesn't need to be in idt if withdraw is only available during payout
                // (bool successB, ) = arrayOfBettersB[i].bettor.call{value: arrayOfBettersB[i].amount}("");
                // require(successB, "Transfer from B failed");
                arrayOfBettersB[i].bettor = payable(address(0));
                emit userWithdrewBet(msg.sender, "B");
                withdrawnB = true;
                arrayOfBettersB[i].bettor.transfer(arrayOfBettersB[i].amount);
                break; // Assuming a user can only be once in the array
            }
        }

        require(withdrawnA || withdrawnB, "No bets found to withdraw");
    }


    function voteDisagree()public payable{
        require((block.timestamp+300) >= endTime && s_raffleState != RaffleState.UNDERREVIEW);
        require(msg.value == 50000000000000000);
        locked += msg.value;
        s_raffleState = RaffleState.UNDERREVIEW;
        disagreeUser = msg.sender;
        emit underReview();
    }

    function endBetOwner(uint8 wlc)public onlyOwner{
        require(block.timestamp>=endTime);
        require(s_raffleState==RaffleState.OPEN);

        require(wlc==0||wlc==1||wlc==2,"invalid input");


        if(wlc==0){
            winner =0;
        }else if(wlc==1){
            winner =1;
        }
        else{
            winner =2;
        }
        voteTime = block.timestamp + 300;
        s_raffleState = RaffleState.VOTING;
        emit winnerDeclaredVoting(wlc,voteTime);
        
    }

    function endBetStaff(uint8 wlc,bool disagreedUserCorrect, bool ownerCorrect)public onlyStaff nonReentrant {
        require(block.timestamp>=endTime);
        require( s_raffleState==RaffleState.UNDERREVIEW);

        require(wlc==0||wlc==1||wlc==2,"invalid input");


        if(wlc==0){
            winner =0;
        }else if(wlc==1){
            winner =1;
        }
        else{
            winner =2;
        }
        if(disagreedUserCorrect == true && ownerCorrect ==false){
            s_raffleState = RaffleState.SETTLED;
            // (bool successB, ) = disagreeUser.call{value: locked}("");
            // require(successB, "Transfer to user failed");
            payable(disagreeUser).transfer(locked);
            emit winnerFinalized(wlc);
            
        }else if(disagreedUserCorrect == false && ownerCorrect ==true){
            s_raffleState = RaffleState.SETTLED;
            // (bool successB, ) = owner.call{value: locked}("");
            // require(successB, "Transfer to user failed");
            payable(owner).transfer(locked);
            emit winnerFinalized(wlc);
        }else{
            s_raffleState = RaffleState.SETTLED;
            if(wlc==0){
                BetA += locked;
            }
            else if(wlc==1){
                BetB += locked;
            }
            else{
                BetA += locked/2;
                BetB += locked/2;
            }
            emit winnerFinalized(wlc);
        }
        
    }



    function betterInfo() public view returns (better memory, better memory) {
        better memory emptyBetter;
        bool foundInA = false;
        bool foundInB = false;
        better memory betterFromA = emptyBetter;
        better memory betterFromB = emptyBetter;

        for (uint i = 0; i < arrayOfBettersA.length; i++) {
            if (msg.sender == arrayOfBettersA[i].bettor) {
                betterFromA = arrayOfBettersA[i];
                foundInA = true;
                break;
            }
        }

        for (uint i = 0; i < arrayOfBettersB.length; i++) {
            if (msg.sender == arrayOfBettersB[i].bettor) {
                betterFromB = arrayOfBettersB[i];
                foundInB = true;
                break;
            }
        }

        if (!foundInA && !foundInB) {
            // Sender not found in either array
            return (emptyBetter, emptyBetter);
        } else {
            // Return the information found
            return (betterFromA, betterFromB);
        }
    }

    function isOwner() public view returns(bool){
        if((msg.sender == owner)||(msg.sender==staffWallet)){
            return true;
        }else{
            return false;
        }
    }

    function getRaffleState() public view returns (RaffleState){
        return s_raffleState;
    }
    function getUserAmount() public view returns(uint){
        uint256 amount;// measures amount won

        for (uint i = 0; i < arrayOfBettersA.length; i++) {
            if (arrayOfBettersA[i].bettor == msg.sender && arrayOfBettersA[i].amount > 0) {
                amount += arrayOfBettersA[i].amount;
                break; // Assuming a user can only be once in the array
            }
        }
        // Withdraw from B
        for (uint i = 0; i < arrayOfBettersB.length; i++) {
            if (arrayOfBettersB[i].bettor == msg.sender && arrayOfBettersB[i].amount > 0) {
                amount += arrayOfBettersB[i].amount;
                break; // Assuming a user can only be once in the array
            }
        }
        return(amount);


    }

    

    

}



