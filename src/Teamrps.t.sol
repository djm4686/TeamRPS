// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.6;

import "ds-test/test.sol";

import "./Teamrps.sol";

abstract contract Hevm {
    // sets the block timestamp to x
    function warp(uint x) public virtual;
    // sets the block number to x
    function roll(uint x) public virtual;
    // sets the slot loc of contract c to val
    function store(address c, bytes32 loc, bytes32 val) public virtual;
}

contract TeamrpsTest is DSTest {
    RPS teamrps;
    Hevm hevm;
    uint gameId;
    uint[] gameIds;
    uint betAmount;
    uint[4] betAmounts;
    uint8 blockLength;

    receive() external payable {
    }

    function setUp() public {
        betAmount = 1000000000000000000;
        betAmounts = [1000, 1000000000, 1000000000000, 1000000000000000000];
        blockLength = 5;
        teamrps = new RPS(betAmount, blockLength, 1);
        hevm = Hevm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
        gameId = teamrps.currentGameId();
        gameIds.push(gameId);
    }

    function testFail_vote_wrong_amount() public {
        teamrps.vote{value: betAmount + 1}(teamrps.getTeamEnum("RED"), teamrps.getVoteEnum("ROCK"));
    }

    function testFail_vote_wrong_team() public {
        teamrps.vote{value: betAmount}(teamrps.getTeamEnum("NONE"), teamrps.getVoteEnum("ROCK"));
    }

    function testFail_vote_wrong_vote() public {
        teamrps.vote{value: betAmount}(teamrps.getTeamEnum("RED"), teamrps.getVoteEnum("NULL"));
    }

    function testFail_vote_block_number() public {
        hevm.roll(blockLength+1);
        teamrps.vote{value: betAmount}(teamrps.getTeamEnum("RED"), teamrps.getVoteEnum("ROCK"));
    }

    function test_vote_then_withdraw_single_player_success() public {
        for(uint i=0; i < betAmounts.length; i++){
          hevm.roll(0);
          betAmount = betAmounts[i];
          teamrps = new RPS(betAmount, blockLength, 1);
          uint prebalance = address(this).balance;
          uint test_count = 5;
          for(uint j=0; j<test_count; j++){
            teamrps.vote{value: betAmount}(teamrps.getTeamEnum("RED"), teamrps.getVoteEnum("ROCK"));
          }
          hevm.roll(blockLength);
          teamrps.endGame();
          teamrps.withdraw(gameIds);
          uint cut = teamrps.calculateCut(betAmount * test_count);
          uint postBalance = address(this).balance;
          assertEq(prebalance - postBalance, cut);
        }
    }

    function test_vote_then_withdraw_multiplayer_success() public {
      payable(address(teamrps)).transfer(100 ether);
      for(uint i=0; i < betAmounts.length; i++){
        hevm.roll(0);
        betAmount = betAmounts[i];
        teamrps = new RPS(betAmount, blockLength, 1);
        uint prebalance = address(this).balance;

        teamrps.vote{value: betAmount}(teamrps.getTeamEnum("RED"), teamrps.getVoteEnum("ROCK"));
        teamrps.vote{value: betAmount}(teamrps.getTeamEnum("RED"), teamrps.getVoteEnum("ROCK"));
        teamrps.vote{value: betAmount}(teamrps.getTeamEnum("RED"), teamrps.getVoteEnum("ROCK"));
        teamrps.vote{value: betAmount}(teamrps.getTeamEnum("BLUE"), teamrps.getVoteEnum("SCISSORS"));
        teamrps.vote{value: betAmount}(teamrps.getTeamEnum("BLUE"), teamrps.getVoteEnum("SCISSORS"));
        teamrps.vote{value: betAmount}(teamrps.getTeamEnum("BLUE"), teamrps.getVoteEnum("SCISSORS"));

        hevm.roll(blockLength);
        teamrps.endGame();
        teamrps.withdraw(gameIds);
        uint cut = teamrps.calculateCut(betAmount * 6);
        uint postBalance = address(this).balance;
        assertEq(prebalance, postBalance + cut);
      }
    }

    function test_vote_then_withdraw_tie_success() public {
      for(uint i=0; i < betAmounts.length; i++){
        hevm.roll(0);
        betAmount = betAmounts[i];
        teamrps = new RPS(betAmount, blockLength, 1);
        uint prebalance = address(this).balance;
        uint pot = 0;

        teamrps.vote{value: betAmount}(teamrps.getTeamEnum("RED"), teamrps.getVoteEnum("ROCK"));
        teamrps.vote{value: betAmount}(teamrps.getTeamEnum("BLUE"), teamrps.getVoteEnum("ROCK"));

        hevm.roll(blockLength);
        teamrps.endGame();
        teamrps.withdraw(gameIds);

        uint cut = teamrps.calculateCut(betAmount * 2);
        pot = betAmount * 2 - cut;
        uint postBalance = address(this).balance;
        assertEq(prebalance, postBalance + (betAmount * 2));

        teamrps.vote{value: betAmount}(teamrps.getTeamEnum("RED"), teamrps.getVoteEnum("ROCK"));
        teamrps.vote{value: betAmount}(teamrps.getTeamEnum("RED"), teamrps.getVoteEnum("ROCK"));

        pot += betAmount * 2;
        hevm.roll((blockLength)*2);

        gameId = teamrps.currentGameId();
        gameIds.push(gameId);
        teamrps.endGame();
        teamrps.withdraw(gameIds);

        cut += teamrps.calculateCut(pot);
        postBalance = address(this).balance;

        assertLt(prebalance - postBalance - cut, 2);
        gameIds.pop();
      }
    }

    function test_withdraw_twice() public {
      payable(address(teamrps)).transfer(1 ether);
      uint prebalance = address(this).balance;
      uint test_count = 5;
      for(uint i=0; i<test_count; i++){
        teamrps.vote{value: betAmount}(teamrps.getTeamEnum("RED"), teamrps.getVoteEnum("ROCK"));
      }
      hevm.roll(blockLength);
      teamrps.endGame();
      teamrps.withdraw(gameIds);
      uint cut = teamrps.calculateCut(betAmount * test_count);
      uint postBalance = address(this).balance;
      assertEq(prebalance - postBalance, cut);

      teamrps.withdraw(gameIds);
      postBalance = address(this).balance;
      assertEq(prebalance - postBalance, cut);
    }

    function testFail_end_game() public {
        teamrps.endGame();
    }

    function testFail_end_game_not_enough_blocks() public {
        hevm.roll(blockLength-1);
        teamrps.endGame();
    }
    function testFail_end_game_not_enough_blocks_two() public {
        hevm.roll(blockLength);
        teamrps.endGame();
        hevm.roll(blockLength * 2 - 1);
        teamrps.endGame();
    }

    function testFail_end_game_two() public {
        hevm.roll(blockLength);
        teamrps.endGame(); //Should succeed;
        teamrps.endGame(); //Should fail;
    }

    function test_end_game_success() public {
        hevm.roll(blockLength);
        teamrps.endGame();
    }

    function test_end_game_success_two() public {
        hevm.roll(blockLength);
        teamrps.endGame();
        hevm.roll((blockLength)*2);
        teamrps.endGame();
    }

    function test_vote_success() public {
        teamrps.vote{value: betAmount}(teamrps.getTeamEnum("RED"), teamrps.getVoteEnum("ROCK"));
        teamrps.vote{value: betAmount}(teamrps.getTeamEnum("BLUE"), teamrps.getVoteEnum("ROCK"));
        teamrps.vote{value: betAmount}(teamrps.getTeamEnum("RED"), teamrps.getVoteEnum("PAPER"));
        teamrps.vote{value: betAmount}(teamrps.getTeamEnum("BLUE"), teamrps.getVoteEnum("PAPER"));
        teamrps.vote{value: betAmount}(teamrps.getTeamEnum("RED"), teamrps.getVoteEnum("SCISSORS"));
        teamrps.vote{value: betAmount}(teamrps.getTeamEnum("BLUE"), teamrps.getVoteEnum("SCISSORS"));
    }


    function testFail_basic_sanity() public {
        assertTrue(false);
    }

    function test_basic_sanity() public {
        assertTrue(true);
    }
}
