// SPDX-License-Identifier: MIT
// 1. Pragma
pragma solidity ^0.8.7;

contract predMarket {

    address private immutable owner;
    uint256 public BetA =0;
    uint256 public BetB = 0;
    RaffleState private s_raffleState;
    uint256 public endTime;
    uint256 public startTime;
    uint256 public voteTime;
    uint8 public winner;
    uint8 public disagree;
    uint256[2] public oddsBetA;
    uint256[2] public oddsBetB;
    error didNotBet(string betAorB);

     

    struct better {
        address payable bettor;
        uint256 amount;
        uint256[2] odds;
    }
    better[] public arrayOfBettersA;
    better[] public arrayOfBettersB;

    constructor(uint256 timeToEnd, uint256 _odds1, uint256 _odds2) {
        s_raffleState = RaffleState.OPEN;
        startTime = block.timestamp;
        endTime = startTime +timeToEnd;
        owner = msg.sender;
        oddsBetA[0] = _odds1;
        oddsBetA[1] = _odds2;
        oddsBetB[0] = _odds2;
        oddsBetB[1] = _odds1;


    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only the owner can call this function.");
        _;
    }


     enum RaffleState {
        OPEN,
        VOTING,
        UNDERREVIEW,
        PAYOUT,
        CLOSED
    }

    function viewPots()public view returns(uint256,uint256){
        return (BetA,BetB);
    }



    function emptyLosingArray(better[] storage arrLost, better[] storage arrWinner)private {
        //Responsible for paying the winner and dedudcting from the losers in the correct order
        uint i = 0;
        while(i<arrWinner.length){
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


    function winLossBetA(uint256 potentialBet) public view returns(uint256,uint256, uint256) {
        bool bettorExists = false;
        uint256 potB = BetB; // Assuming BetB is declared somewhere in your contract
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
            arrWinner = new better[](arrayOfBettersA.length + 1);
            for (uint i = 0; i < arrayOfBettersA.length; i++) {
                arrWinner[i] = arrayOfBettersA[i];
            }
            arrWinner[arrayOfBettersA.length] = better(payable(msg.sender), potentialBet, oddsBetA);
            betterPosition = arrayOfBettersA.length;
        } else {
            arrWinner = arrayOfBettersA;
            arrWinner[betterPosition].amount += potentialBet;
            // Note: This does not actually modify the array; it's for calculation purposes
        }

        // Calculate winnings and risks
        uint256 payout;
        uint256 risk;
        uint256 payout2;
        for (uint i = 0; i < arrWinner.length; i++) {
            payout = (arrWinner[i].amount * oddsBetA[0]) / oddsBetA[1];
            payout2 = payout;
            if (i == betterPosition) {
                if (potB < payout) {
                    return (payout2, potB, (potB * oddsBetA[1]) / oddsBetA[0]);
                } else {
                    risk = (payout * oddsBetA[1]) / oddsBetA[0];
                    return (payout2, payout, arrWinner[i].amount);
                }
            } else {
                if (potB >= payout) {
                    potB -= payout;
                }
            }
        }
        return (payout2,0, 0); // Return default values if no condition is met
    }

    function winLossBetB(uint256 potentialBet) public view returns(uint256, uint256, uint256) {
        bool bettorExists = false;
        uint256 potA = BetA; // Assuming BetA is declared somewhere in your contract
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
            arrWinner = new better[](arrayOfBettersB.length + 1);
            for (uint i = 0; i < arrayOfBettersB.length; i++) {
                arrWinner[i] = arrayOfBettersB[i];
            }
            arrWinner[arrayOfBettersB.length] = better(payable(msg.sender), potentialBet, oddsBetB);
            betterPosition = arrayOfBettersB.length;
        } else {
            arrWinner = arrayOfBettersB;
            arrWinner[betterPosition].amount += potentialBet;
            // Note: This does not actually modify the array; it's for calculation purposes
        }

        // Calculate winnings and risks
        uint256 payout;
        uint256 risk;
        uint256 payout2;
        for (uint i = 0; i < arrWinner.length; i++) {
            payout = (arrWinner[i].amount * oddsBetB[0]) / oddsBetB[1];
            payout2 = payout;
            if (i == betterPosition) {
                if (potA < payout) {
                    return (payout2, potA, (potA * oddsBetB[1]) / oddsBetB[0]);
                } else {
                    risk = (payout * oddsBetB[1]) / oddsBetB[0];
                    return (payout2 ,payout, arrWinner[i].amount);
                }
            } else {
                if (potA >= payout) {
                    potA -= payout;
                }
            }
        }
        return (payout2, 0, 0); // Return default values if no condition is met
    }


//     function viewPotentialWinningsAndPotentialRiskA(uint256 potentialBet)public view returns(uint256,uint256) {
//         //Responsible for paying the winner and dedudcting from the losers in the correct order
//         uint i = 0;
//         better[] memory arrWinner = arrayOfBettersA;
//         better[] memory arrLost = arrayOfBettersB;

//         uint j =0;
//         uint arrOfWinner;
//         uint previousBet = 0;

        


//         while(j<arrWinner.length){
//             if(msg.sender == arrWinner[j].bettor){
//                 arrOfWinner = j;
//                 previousBet += arrWinner[j].amount + potentialBet;
//                 arrWinner[j].amount += potentialBet;
        
//             }else{
//             if(j+1 == arrWinner.length ){
//                 better memory newbetter = better(payable(msg.sender),potentialBet,oddsBetA);

//                 previousBet += potentialBet;
//                 arrOfWinner = j+1;
//                 arrWinner = new better[](j+2);
//                 for(uint z = 0; z<=arrOfWinner;z++){
//                     if(z == arrOfWinner){
//                         arrWinner[z] = newbetter;
//                     }else{
//                         arrWinner[z] = arrayOfBettersA[z];
//                     }
                    
//                 }
//             }
//             j++;
//             }
//         }

//         while(i<arrWinner.length){
           
//             uint x = 0;
//             uint winnerNeeds = (arrWinner[i].amount * arrWinner[i].odds[0])/arrWinner[i].odds[1] ;

//             while (x < arrLost.length) {
//                 if (arrLost[x].amount <= 0) {
//                     x++; // Move to the next element if the current element is 0
//                 } else if (arrLost[x].amount > winnerNeeds) {
//                     arrLost[x].amount -= winnerNeeds;
//                     arrWinner[i].amount += winnerNeeds;
//                     break;
//                      // Winner keeps original value and receives additional amount based on the odds
//                     // Removed console.log as it's not supported in Solidity
//                     // break; // Break is not necessary as return already exits the function
//                 } else {
//                     winnerNeeds -= arrLost[x].amount;
//                     arrWinner[i].amount += arrLost[x].amount;
//                     arrLost[x].amount = 0; // Set the current element to 0
//                     x++; // Move to the next element
//                 }
//             }
//             i++;
        
//     }
//     uint256 reward = arrWinner[j].amount - previousBet;
//     uint256 risk = (reward*arrWinner[0].odds[1])/arrWinner[0].odds[0];
//     return(reward,risk);
//     //Risk = (reward*odds[1])/odds[0]

//    }

//    function viewPotentialWinningsAndPotentialRiskB(uint256 potentialBet)public view returns(uint256,uint256) {
//         //Responsible for paying the winner and dedudcting from the losers in the correct order
//         uint i = 0;
//         better[] memory arrWinner = arrayOfBettersB;
//         better[] memory arrLost = arrayOfBettersA;

//         uint j =0;
//         uint arrOfWinner;
//         uint previousBet = 0;

        


//         while(j<arrWinner.length){
//             if(msg.sender == arrWinner[j].bettor){
//                 arrOfWinner = j;
//                 previousBet += arrWinner[j].amount + potentialBet;
//                 arrWinner[j].amount += potentialBet;
        
//             }else{
//             if(j+1 == arrWinner.length ){
//                 better memory newbetter = better(payable(msg.sender),potentialBet,oddsBetB);

//                 previousBet += potentialBet;
//                 arrOfWinner = j+1;
//                 arrWinner = new better[](j+2);
//                 for(uint z = 0; z<=arrOfWinner;z++){
//                     if(z == arrOfWinner){
//                         arrWinner[z] = newbetter;
//                     }else{
//                         arrWinner[z] = arrayOfBettersB[z];
//                     }
                    
//                 }
//             }
//             j++;
//             }
//         }

//         while(i<arrWinner.length){
           
//             uint x = 0;
//             uint winnerNeeds = (arrWinner[i].amount * arrWinner[i].odds[0])/arrWinner[i].odds[1] ;

//             while (x < arrLost.length) {
//                 if (arrLost[x].amount <= 0) {
//                     x++; // Move to the next element if the current element is 0
//                 } else if (arrLost[x].amount > winnerNeeds) {
//                     arrLost[x].amount -= winnerNeeds;
//                     arrWinner[i].amount += winnerNeeds;
//                     break;
//                      // Winner keeps original value and receives additional amount based on the odds
//                     // Removed console.log as it's not supported in Solidity
//                     // break; // Break is not necessary as return already exits the function
//                 } else {
//                     winnerNeeds -= arrLost[x].amount;
//                     arrWinner[i].amount += arrLost[x].amount;
//                     arrLost[x].amount = 0; // Set the current element to 0
//                     x++; // Move to the next element
//                 }
//             }
//             i++;
        
//     }
//     uint256 reward = arrWinner[j].amount - previousBet;
//     uint256 risk = (reward*arrWinner[0].odds[1])/arrWinner[0].odds[0];
//     return(reward,risk);
//     //Risk = (reward*odds[1])/odds[0]

//    }

   function getBalance() public view returns (uint) {
        return address(this).balance;
    }


    function assignEveryoneAmount() public onlyOwner{
        require(s_raffleState== RaffleState.VOTING);
        require(block.timestamp>=voteTime);
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

    }
    // function payoutA() public{
        // uint x = 0;
        // uint pot =  BetB;


        // while(x<arrayOfBettersA.length){
        //     if((arrayOfBettersA[x].amount*arrayOfBettersA[x].odds[0])/arrayOfBettersA[x].odds[1] <= pot){
        //         pot -= (arrayOfBettersA[x].amount*arrayOfBettersA[x].odds[0])/arrayOfBettersA[x].odds[1];
        //         (arrayOfBettersA[x].amount) = emptyLosingArray(arrayOfBettersB,arrayOfBettersA[x].amount,arrayOfBettersA[x].odds);
        //         (bool success, ) = arrayOfBettersA[x].bettor.call{value: arrayOfBettersA[x].amount}("");
        //         require(success, "Transfer failed");
        //     }
        //     else{
        //         (arrayOfBettersA[x].amount) = emptyLosingArray(arrayOfBettersB,arrayOfBettersA[x].amount,arrayOfBettersA[x].odds);
        //         (bool success, ) = arrayOfBettersA[x].bettor.call{value: pot}("");
        //         require(success, "Transfer failed");
        //         pot = 0;
        //     }

        //     }
        // uint i = 0;
        // while(i<arrayOfBettersB.length){
        //     if(arrayOfBettersB[i].amount == 0 ){
        //         i++;
        //     }else{
        //     (bool success, ) = arrayOfBettersB[i].bettor.call{value: arrayOfBettersB[i].amount}("");
        //     require(success, "Transfer failed");
        //     }
        //     }
        //  }
    // function returnAll(better[] storage betA,better[] storage betB)public{
    //     uint x = 0;
    //     uint i = 0;
    //     while(x<betA.length){
    //         (bool success, ) = betA[x].bettor.call{value: betA[x].amount}("");
    //         require(success, "Transfer failed");
    //     }
    //     while(i<betB.length){
    //         (bool success, ) = betB[i].bettor.call{value: betB[i].amount}("");
    //         require(success, "Transfer failed");
    //     }
    // }



    

//    for (let i = 0; i < arrayA.length; i++) {
//     if (arrayA[i] * 3 <= potB) {
//         arrayA[i] = emptyArray(arrayB, arrayA[i]); // Update arrayA[i] with the returned value
//         potB -= arrayA[i] * 3;
//     } else {
//         arrayA[i] =emptyArray(arrayB, arrayA[i]);
//         potB = 0;
//     }
// }


    
   
    function betOnBetA() public payable returns(uint){
        require(s_raffleState== RaffleState.OPEN);
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
        return 0;
    }

    function betOnBetB() public payable returns(uint){
        require(s_raffleState== RaffleState.OPEN);
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
        return 0;
    }

    function reduceBetA(uint256 reduction)public{
        require(s_raffleState== RaffleState.OPEN);
        uint i = 0;
        while(i<arrayOfBettersA.length){
            if(arrayOfBettersA[i].bettor==msg.sender){
                if(arrayOfBettersA[i].amount>= reduction){
                    
                    (bool success, ) = arrayOfBettersA[i].bettor.call{value: reduction}("");
                    require(success, "Transfer failed");
                    arrayOfBettersA[i].amount -= reduction;
                    BetA -= reduction;
                    break;
                }else{
                    if(i == arrayOfBettersA.length -1 ){
                        revert didNotBet("Not On Bet A");
                    }
                    
                }
            }
            else{
                i++;
            }
        }
    }
    function reduceBetB(uint256 reduction)public{
        require(s_raffleState== RaffleState.OPEN);
        uint i = 0;
        while(i<arrayOfBettersB.length){
            if(arrayOfBettersB[i].bettor==msg.sender){
                if(arrayOfBettersB[i].amount>= reduction){
                    (bool success, ) = arrayOfBettersB[i].bettor.call{value: reduction}("");
                    require(success, "Transfer failed");
                    arrayOfBettersB[i].amount -= reduction;
                    BetB -= reduction;
                    break;
                }else{
                    if(i == arrayOfBettersB.length -1 ){
                        revert didNotBet("Not On Bet B");
                    }

                }
            }
            else{
                i++;
            }
        }
    }

    function withdrawA()public{
        // require( s_raffleState== RaffleState.PAYOUT);
        uint i = 0;
        while(i<arrayOfBettersA.length){
            if(arrayOfBettersA[i].bettor==msg.sender){
                if(arrayOfBettersA[i].amount > 0){
                    (bool success, ) = arrayOfBettersA[i].bettor.call{value: arrayOfBettersA[i].amount}("");
                    require(success, "Transfer failed");
                    break;
                }
            }
            else{
                i++;
            }
        }

    }

    function withdrawB()public{
        require(s_raffleState== RaffleState.PAYOUT);
        uint i = 0;
        while(i<arrayOfBettersB.length){
            if(arrayOfBettersB[i].bettor==msg.sender){
                if(arrayOfBettersB[i].amount >0){
                    (bool success, ) = arrayOfBettersB[i].bettor.call{value: arrayOfBettersB[i].amount}("");
                    require(success, "Transfer failed");
                    break;
                }
            }
            else{
                i++;
            }
        }

    }

    function voteDisagree()public{
        require(s_raffleState== RaffleState.VOTING);
        disagree +=1;
        if(disagree>=5){
            s_raffleState = RaffleState.UNDERREVIEW;
        }
    }

    function endBet(uint8 wlc)public onlyOwner{
        //owner determines winner
        // require(s_raffleState== RaffleState.OPEN);
        // require(block.timestamp>=endTime);

        require(wlc==0||wlc==1||wlc==2,"invalid input");


        if(wlc==0){
            winner =0;
        }else if(wlc==1){
            winner =1;
        }
        else{
            winner =2;
            
        }
        s_raffleState = RaffleState.VOTING;
        voteTime = block.timestamp + 86400;
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
        if(msg.sender == owner){
            return true;
        }else{
            return false;
        }
    }

    function getRaffleState() public view returns (RaffleState){
        return s_raffleState;
    }

    

    

}



