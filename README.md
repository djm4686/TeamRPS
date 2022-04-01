# TeamRPS
An ethereum smart contract for a blockchain-based gambling game built with solidity: team-based rock paper scissors

## How it works:

For those of you that live under a rock, a normal rock-paper-scissors game is played between two players. The game begins when both players simultaneously hold out their hands and say the words "rock, paper, scissors, shoot!" When the word "shoot" is said, each player forms their hand into one of three gestures, each one signifying either rock, paper, or scissors respectively. The winner of the game is the person who gestured with the "better" of the two displayed gestures. Paper beats rock, rock beats scissors, and scissors beats paper. If both players display the same gesture, the game is a tie.

Team RPS takes this into another level. The first game begins when the contract is published. It is published with three parameters: The bet amount, the number of blocks each game will last, as well as the cut the owner of the contract takes from each pot.

The bet amount is immutable and is considered the cost of participating in a game.
The number of blocks is better explained with an example. Assume the number of blocks set is 5. Also assume that the current game of TeamRPS was initialized in block 20. This means that at block 26, the game is considered over and players can no longer participate in this game. Payouts from that game can be requested via the withdraw() function. A new game can be started in block >=26 by calling the endGame() function. This causes the start block to become the block in which endGame() was called.

## How to play the game:

The game has two states: active and inactive.

    Active: The current block is less than or equal to the start block plus the number of blocks specified during creation
      e.g. a game started on block 20 with a game length of 10 blocks would be active during blocks 20-30.
    Inactive: The current block is greater than the start block plus the number of blocks specified during creation
      e.g. a game started on block 20 with a game length of 10 blocks would be inactive on any blocks other than 20-30.

While the game is active players may vote() for a team and either rock, paper, or scissors. Players can vote() multiple times, each time paying the betAmount specified in the contract. Players may vote for any combination of teams and gestures. This means that you can vote for both the red team and the blue team at the same time. There are three reasons you may want to vote for both teams: to recover obvious losses, to hedge your bet, or to sabotage the team you don't want to win. Votes are publicly viewable, but are immutable and cannot be changed.

Note: You may not vote more than 100 times per game. This is to prevent out-of-gas exceptions when calling withdrawWinnings()

A winner is determined once the game becomes inactive. The votes for each gesture for each team are summed, and the winning vote is that team's gesture. The team with the "better" gesture is the winner.

Example:

    Red Team:
      Votes:
        Rock: 6
        Paper: 12
        Scissors: 11

    Blue Team:
      Votes:
        Rock:3
        Paper:4
        Scissors:11

In the above example the Red team's gesture is determined to be Paper, and the Blue team's gesture is Scissors. Following normal rules of normal RPS, the Blue team wins.

## Payout

Lets assume that the betAmount for the above game was 1 ETH. Lets sum the total amount of votes there were:

  6+12+11+3+4+11 = 47

Each vote MUST have paid EXACTLY the betAmount to have their vote considered, so the total pot was 47 ETH. The winners were the blue team, which had 18 votes. Splitting 47 ETH evenly would pay out over 2.75 ETH to each player. In reality, the payout might be slightly less, as the owner of the contract may take a small cut from the overall pot.

To be paid out, the player calls the withdrawWinnings() function, passing in all of the gameIds of the games they wish to withdrawWinnings from. When the contract is created, the first game played has a gameId of 0. Each time endGame() is called, 1 is added to the gameId. Therefore, looping through the range of numbers between (0, currentGameId) will yield every game. This list is public, so you can see which gameIds you are owed money for without sending a transaction. The withdraw function is limited to 100 gameIds, to prevent an out-of-gas situation.

Note: Before calling withdrawWinnings() with a particular gameId, that game must have been ended with endGame().

## Ties

In the event of a tie, the pot is passed down to the next game. All votes are wiped, and players must vote() again.

## Nerdy details

There are 3 public functions:

    vote(enum Team, enum Vote) payable;

    endGame();

    withdrawWinnings(uint[] gameIds);


There are 9 public attributes:

    address public owner; // The address of the owner of the contract. The only one who can call withdrawOwner();
    uint public ownerCut; // The % cut of each pot the owner takes.
    uint public ownerValue; // The total value in the contract allocated to the owner.
    uint public currentGameId; // The current gameId. This starts with 0 and iterates by 1 each time endGame() is called.
    uint public betAmount; // The amount a voter needs to send to call the vote() function.
    uint8 public blockLength; // The amount of blocks the game will last.
    mapping(address => mapping(uint => Bet[])) public playerBets; // All the bets that have not yet been withdrawn with withdrawWinnings().
    Game[] public gameHistory; // A list that contains the ending state of all games that have ever been played indexed by their gameId.
    Game public game; // The current state of the game

The Game struct contains 12 members

    struct Game {
        uint pot; // The total pot of the game
        uint redPlayerCount; // The total number of bets for the Red team.
        uint bluePlayerCount; // The total number of bets for the Blue team.
        uint redRockVotes; // The total number of Red team Votes that were Rock.
        uint redPaperVotes; // The total number of Red team Votes that were Paper.
        uint redScissorsVotes; // The total number of Red team Votes that were Scissors.
        uint blueRockVotes; // The total number of Blue team Votes that were Rock.
        uint bluePaperVotes; // The total number of Blue team Votes that were Paper.
        uint blueScissorsVotes; // The total number of Blue team Votes that were Scissors.
        uint startBlock; // The block denoting the beginning of the Game's active period.
        Vote lastRedVote; // The last Vote a member of the Red team made.
        Vote lastBlueVote; // The last Vote a member of the Blue team made.
    }


### vote(enum Team, enum Vote) payable;

vote() takes two enums, the team you want to vote for, and the vote itself.
The enums are defined as:

    enum Team { RED, BLUE, NONE }

    enum Vote { ROCK, PAPER, SCISSORS, NULL }

Note that Team.NONE and Vote.NULL are for internal data initialization only, and should not be used as parameters. The function call will fail if you send either of those values.

The value of eth that should be sent along with your vote() is defined by the public attribute in the contract called "betAmount";

### endGame();

endGame() can only be called when the game is inactive. It pushes the current game onto the gameHistory array, then initializes a new game. If the last game was a tie, the game's initial pot will be the total pot of the last game. The startBlock of the new game is the block in which endGame() is called. All votes for all teams are wiped, and the new game becomes active.

### withdrawWinnings(uint[] gameIds);

withdrawWinnings() takes in a list of gameIds, limited to a total of 100 Ids to help prevent out-of-gas issues. This loops through the history of all of the games supplied in the parameter, and tallies up the winnings of any game for which you bet on the winning team. It then transfer the entire amount tallied over all games to your wallet. The payout of each game works as follows:

    p = total pot in the game minus any owner cuts

    w = total amount of bets for the winning team

    b = total amount of bets YOU made for the winning team

    t = total payout

    t = (p / w) *

The calculations to determine who won a game and who gets the payout is actually done every time withdrawWinnings() is called.

Note: Due to math in solidity not having floating points, the above calculation is rounded down. So you may receive 1 WEI less than you should have. 1 WEI is 1 attoether, or 0.000000000000000001 ETH. At current prices that's worth .0000000000000032052 USD so nobody should really be complaining too much.

Note: withdrawWinnings() will throw an error if you try to give it a gameId that hasnt happened, or the current gameId.

## Testing

The tests for this smart contract are built with dapp, and it is a dependency to run them.

The run the tests, invoke the following command from the root directory of the project:

    dapp test
