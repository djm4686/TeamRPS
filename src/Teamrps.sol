// SPDX-License-Identifier: GPL-3.0
pragma solidity >= 0.8.6;

contract RPS {

    enum Team { RED, BLUE, NONE }
    enum Vote { ROCK, PAPER, SCISSORS, NULL }
    enum Winner { REDPAPER, REDROCK, REDSCISSORS, BLUEPAPER, BLUEROCK, BLUESCISSORS, TIE }

    // Used solely for exposing the enums to the test harness
    function getTeamEnum(string calldata req) external pure returns (Team) {
      if(keccak256(abi.encodePacked(req)) == keccak256("RED")){
        return Team.RED;
      }
      if(keccak256(abi.encodePacked(req)) == keccak256("BLUE")){
        return Team.BLUE;
      }
      if(keccak256(abi.encodePacked(req)) == keccak256("NONE")){
        return Team.NONE;
      }
      revert();
    }

    // Used solely for exposing the enums to the test harness
    function getVoteEnum(string calldata req) external pure returns (Vote) {
      if(keccak256(abi.encodePacked(req)) == keccak256("ROCK")){
        return Vote.ROCK;
      }
      if(keccak256(abi.encodePacked(req)) == keccak256("PAPER")){
        return Vote.PAPER;
      }
      if(keccak256(abi.encodePacked(req)) == keccak256("SCISSORS")){
        return Vote.SCISSORS;
      }
      if(keccak256(abi.encodePacked(req)) == keccak256("NULL")){
        return Vote.NULL;
      }
      revert();
    }

    address public owner; // The owner of the contract
    uint public ownerCut; // The amount the owner gets per pot
    uint public ownerValue; // The value the owner can withdraw
    uint public currentGameId; // The id of the current Game state.
    uint public betAmount; // The amount needed to pay to vote()
    uint8 public blockLength; // The number of blocks each game lasts for.

    // The structure stored for each bet.
    struct Bet {
        Team team;
        Vote vote;
    }

    // The strcuture for the game state.
    struct Game {
        uint pot;
        uint redPlayerCount;
        uint bluePlayerCount;
        uint redRockVotes;
        uint redPaperVotes;
        uint redScissorsVotes;
        uint blueRockVotes;
        uint bluePaperVotes;
        uint blueScissorsVotes;
        uint startBlock;
        Vote lastRedVote;
        Vote lastBlueVote;
    }

    // This is a mapping of each player to each game state to each bet they made in that game.
    mapping(address => mapping(uint => Bet[])) public playerBets;
    // This is a list of the state of all previous games indexed by their gameId
    Game[] public gameHistory;
    // The current game state
    Game public game;

    // Called when the contract is published to the blockchain
    constructor(uint bet, uint8 numBlocks, uint cut){
        owner = msg.sender;
        betAmount = bet;
        blockLength = numBlocks;
        ownerCut = cut;
        currentGameId = 0;
        createNewGame(0);
    }

    // An internal function used to create a new game state
    // potLeftover should be 0 unless the last game was a tie.
    function createNewGame(uint potLeftover) internal {
        game = Game({
            pot: potLeftover,
            redPlayerCount: 0,
            bluePlayerCount: 0,
            redRockVotes: 0,
            redPaperVotes: 0,
            redScissorsVotes: 0,
            bluePaperVotes: 0,
            blueRockVotes: 0,
            blueScissorsVotes: 0,
            startBlock: block.number,
            lastRedVote: Vote.NULL,
            lastBlueVote: Vote.NULL
        });
    }

    // A helper function to convert uint types to strings for error messages
    function uint2str(uint _i) internal pure returns (string memory _uintAsString) {
        if (_i == 0) {
            return "0";
        }
        uint j = _i;
        uint len;
        while (j != 0) {
            len++;
            j /= 10;
        }
        bytes memory bstr = new bytes(len);
        uint k = len;
        while (_i != 0) {
            k = k-1;
            uint8 temp = (48 + uint8(_i - _i / 10 * 10));
            bytes1 b1 = bytes1(temp);
            bstr[k] = b1;
            _i /= 10;
        }
        return string(bstr);
    }

    // The function to vote for a particular team and gesture.
    // The amount sent MUST be EQUAL to the betAmount attribute
    function vote(Team team, Vote v) public payable {
        // Require the bet amount to be right.
        require(msg.value == betAmount, string(abi.encodePacked("Wrong bet amount. The bet amount must be: ",
         uint2str(betAmount), " WEI. You provided: ",
          uint2str(msg.value), " WEI.")));
        // Require that the team is valid
        require(team == Team.RED || team == Team.BLUE,
           "Bad team assignment. Please choose either the Red or Blue team.");
        // Require that the vote is valid
        require(v == Vote.ROCK || v == Vote.PAPER || v == Vote.SCISSORS,
           "Bad vote. Please vote for Rock, Paper, or Scissors.");
        // Require that the game is active.
        require(block.number <= game.startBlock + blockLength,
           string(abi.encodePacked("Game inactive. Current block: ",
             uint2str(block.number), " --- Starting block: ",
             uint2str(game.startBlock), " --- Game Length: ",
             uint2str(blockLength))));
        // Require the player hasnt voted too many times this game.
        require(playerBets[msg.sender][currentGameId].length < 100,
           "You have made too many votes this game.");
        game.pot += betAmount;
        if(team == Team.RED){
            game.redPlayerCount += 1;
            if(v == Vote.ROCK){
                game.redRockVotes += 1;
                game.lastRedVote = Vote.ROCK;
            }
            else if(v == Vote.PAPER){
                game.redPaperVotes += 1;
                game.lastRedVote = Vote.PAPER;
            }
            else if(v == Vote.SCISSORS){
                game.redScissorsVotes += 1;
                game.lastRedVote = Vote.SCISSORS;
            }
        }
        else if(team == Team.BLUE){
            game.bluePlayerCount += 1;
            if(v == Vote.ROCK){
                game.blueRockVotes += 1;
                game.lastBlueVote = Vote.ROCK;
            }
            else if(v == Vote.PAPER){
                game.bluePaperVotes += 1;
                game.lastBlueVote = Vote.PAPER;
            }
            else if(v == Vote.SCISSORS){
                game.blueScissorsVotes += 1;
                game.lastBlueVote = Vote.SCISSORS;
            }
        }
        else{
          // Bad state. Shouldnt get here but its good to revert if it does.
          revert();
        }
        // Add the bet so we can reference it later in withrawWinnings()
        playerBets[msg.sender][currentGameId].push(Bet({
            vote: v,
            team: team
        }));
    }

    // An internal function. Based on the gameid, it returns a Winner enum value showing the result of the game.
    function determineWinner(uint gameId) internal view returns (Winner winner){
        require(gameId >= 0 && gameId <= currentGameId);
        Game memory g = gameHistory[gameId];
        Vote redWinner = Vote.NULL;
        uint redWinnerCount = 0;
        Vote blueWinner = Vote.NULL;
        uint blueWinnerCount = 0;
        // Check which vote is highest.
        // The last vote made breaks ties.
        if(g.redPaperVotes > redWinnerCount || (g.redPaperVotes >= redWinnerCount && g.lastRedVote == Vote.PAPER)){
            redWinner = Vote.PAPER;
            redWinnerCount = g.redPaperVotes;
        }
        else if(g.redRockVotes > redWinnerCount || (g.redRockVotes >= redWinnerCount && g.lastRedVote == Vote.ROCK)){
            redWinner = Vote.ROCK;
            redWinnerCount = g.redRockVotes;
        }
        else if(g.redScissorsVotes > redWinnerCount || (g.redScissorsVotes >= redWinnerCount && g.lastRedVote == Vote.SCISSORS)){
            redWinner = Vote.SCISSORS;
            redWinnerCount = g.redScissorsVotes;
        }
        if(g.bluePaperVotes > blueWinnerCount || (g.bluePaperVotes >= blueWinnerCount && g.lastBlueVote == Vote.PAPER)){
            blueWinner = Vote.PAPER;
            blueWinnerCount = g.bluePaperVotes;
        }
        else if(g.blueRockVotes > blueWinnerCount || (g.blueRockVotes >= blueWinnerCount && g.lastBlueVote == Vote.ROCK)){
            blueWinner = Vote.ROCK;
            blueWinnerCount = g.blueRockVotes;
        }
        else if(g.blueScissorsVotes > blueWinnerCount || (g.blueScissorsVotes >= blueWinnerCount && g.lastBlueVote == Vote.SCISSORS)){
            blueWinner = Vote.SCISSORS;
            blueWinnerCount = g.blueScissorsVotes;
        }
        // Checks for if nobody voted on one team
        if(redWinnerCount == 0 && blueWinnerCount > 0){
            return Winner.BLUEPAPER;
        }
        else if(redWinnerCount > 0 && blueWinnerCount == 0){
            return Winner.REDPAPER;
        }
        // Check for tie
        if(blueWinner == redWinner){
            return Winner.TIE;
        }
        // Return the proper winner otherwise
        if(blueWinner == Vote.ROCK){
            if(redWinner == Vote.PAPER){
                return Winner.REDPAPER;
            }
            if(redWinner == Vote.SCISSORS){
                return Winner.BLUEROCK;
            }
        }
        if(blueWinner == Vote.PAPER){
            if(redWinner == Vote.ROCK){
                return Winner.BLUEPAPER;
            }
            if(redWinner == Vote.SCISSORS){
                return Winner.REDSCISSORS;
            }
        }
        if(blueWinner == Vote.SCISSORS){
            if(redWinner == Vote.ROCK){
                return Winner.REDROCK;
            }
            if(redWinner == Vote.PAPER){
                return Winner.BLUESCISSORS;
            }
        }
        // Bad state. Shouldnt ever get here, but if it does its good to revert.
        revert();
    }

    // An internal function.
    // It returns true if the Team enum given is considered a winner based on the Winner enum given.
    function isWinner(Team t, Winner w) internal pure returns (bool winner) {
        if(w == Winner.TIE){
            return false;
        }
        if(t == Team.RED){
            if(w == Winner.REDPAPER || w == Winner.REDROCK || w == Winner.REDSCISSORS){
                return true;
            }
        }
        if(t == Team.BLUE){
            if(w == Winner.BLUEPAPER || w == Winner.BLUEROCK || w == Winner.BLUESCISSORS){
                return true;
            }
        }
        return false;
    }

    // This function must be called when the game is over to start a new game.
    // It calculates the owner's cut, pushes the current game state to the gameHistory,
    // And creates a new game state.
    function endGame() public {
        // Ensure the game is inactive
        require(game.startBlock + blockLength <= block.number);
        // Calculate owner cut
        uint cut = calculateCut(game.pot);
        game.pot -= cut;
        ownerValue += cut;
        // Push the game history
        gameHistory.push(game);
        Winner winner = determineWinner(currentGameId);
        // If the game is a tie, pass down the current pot to the new game.
        if(winner == Winner.TIE){
            createNewGame(game.pot);
        }
        else{
            createNewGame(0);
        }
        currentGameId += 1;

    }

    // The function used to calculate the amount to give to the owner of the contract
    function calculateCut(uint pot) public view returns (uint){
        return pot * ownerCut / 10000;
    }

    // This function calculates the payout that should be given based on the
    // number of winning players in that game.
    function getPayout(uint gameId) internal view returns (uint payout) {
        require(gameId >= 0 && gameId < currentGameId);
        uint payoutAmount = 0;
        Game memory g = gameHistory[gameId];
        if(isWinner(Team.RED, determineWinner(gameId))){
            payoutAmount = g.pot / g.redPlayerCount;
        }
        else if(isWinner(Team.BLUE, determineWinner(gameId))){
            payoutAmount = g.pot / g.bluePlayerCount;
        }
        return payoutAmount;
    }

    // This function is called when a player wants to withdraw their winnings.
    // It takes in a list of gameIds, and loops over ethereum
    // For each gameId given, it calculates how much the sender is owed Based
    // on the result of that game.
    function withdrawWinnings(uint[] calldata gameIds) public {
        require(gameIds.length < 100);
        uint payout = 0;
        for(uint j=0; j < gameIds.length; j++){
            require(gameIds[j] >= 0 && gameIds[j] < currentGameId,
               string(abi.encodePacked("gameId provided is out of range: ",
                uint2str(currentGameId),
                " -- Please provide a valid gameId between 0 and ",
                uint2str(currentGameId))));
            Bet[] memory bets = playerBets[msg.sender][gameIds[j]];
            Winner winner = determineWinner(gameIds[j]);
            if(bets.length > 0){
                for(uint k = 0; k < bets.length; k++){
                    if(isWinner(bets[k].team, winner)){
                        payout += getPayout(gameIds[j]);
                    }
                }
            }
            delete playerBets[msg.sender][gameIds[j]];
        }
        payable(msg.sender).transfer(payout);
    }

    // This function is so the owner of the contract can withdraw their cut.
    function withdrawOwner() public {
      require(msg.sender == owner);
      ownerValue = 0;
      payable(msg.sender).transfer(ownerValue);
    }

    // This is used for testing
    receive() external payable {
    }

}
