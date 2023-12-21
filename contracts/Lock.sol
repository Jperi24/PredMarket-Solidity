// SPDX-License-Identifier: MIT
// 1. Pragma
pragma solidity ^0.8.7;

contract predMarket {

    address private immutable owner;
    uint256 public BetA;
    uint256 public BetB;
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
                    arrayOfBettersA[i].amount -= reduction;
                    (bool success, ) = arrayOfBettersA[i].bettor.call{value: reduction}("");
                    require(success, "Transfer failed");
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
                    arrayOfBettersB[i].amount -= reduction;
                    (bool success, ) = arrayOfBettersB[i].bettor.call{value: reduction}("");
                    require(success, "Transfer failed");
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
        require( s_raffleState== RaffleState.PAYOUT);
        uint i = 0;
        while(i<arrayOfBettersA.length){
            if(arrayOfBettersA[i].bettor==msg.sender){
                (bool success, ) = arrayOfBettersA[i].bettor.call{value: arrayOfBettersA[i].amount}("");
                require(success, "Transfer failed");
                break;
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
                (bool success, ) = arrayOfBettersB[i].bettor.call{value: arrayOfBettersB[i].amount}("");
                require(success, "Transfer failed");
                break;
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
        require(s_raffleState== RaffleState.OPEN);
        require(block.timestamp>=endTime);

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

    

}



