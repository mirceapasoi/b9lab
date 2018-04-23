pragma solidity ^0.4.23;

import "truffle/Assert.sol";
import "truffle/DeployedAddresses.sol";
import "../contracts/RockPaperScissors.sol";

contract TestRockPaperScissors {
    function assertOutcome(RockPaperScissors.Outcome a, RockPaperScissors.Outcome b) private {
        Assert.equal(uint(a), uint(b), "error!");
    }

    function testHandsNoOutcome() public {
        RockPaperScissors rps = RockPaperScissors(DeployedAddresses.RockPaperScissors());
        var Move = RockPaperScissors.Move;
        var Outcome = RockPaperScissors.Outcome;

        assertOutcome(rps.getOutcome(Move.ROCK, Move.PAPER), Outcome.LOSE);
        assertOutcome(rps.getOutcome(Move.PAPER, Move.SCISSORS), Outcome.LOSE);
        assertOutcome(rps.getOutcome(Move.SCISSORS, Move.ROCK), Outcome.LOSE);

        assertOutcome(rps.getOutcome(Move.PAPER, Move.ROCK), Outcome.WIN);
        assertOutcome(rps.getOutcome(Move.SCISSORS, Move.PAPER), Outcome.WIN);
        assertOutcome(rps.getOutcome(Move.ROCK, Move.SCISSORS), Outcome.WIN);

        assertOutcome(rps.getOutcome(Move.NONE, Move.PAPER), Outcome.LOSE);
        assertOutcome(rps.getOutcome(Move.NONE, Move.SCISSORS), Outcome.LOSE);
        assertOutcome(rps.getOutcome(Move.NONE, Move.ROCK), Outcome.LOSE);

        assertOutcome(rps.getOutcome(Move.ROCK, Move.NONE), Outcome.WIN);
        assertOutcome(rps.getOutcome(Move.PAPER, Move.NONE), Outcome.WIN);
        assertOutcome(rps.getOutcome(Move.SCISSORS, Move.NONE), Outcome.WIN);

        assertOutcome(rps.getOutcome(Move.ROCK, Move.ROCK), Outcome.TIE);
        assertOutcome(rps.getOutcome(Move.PAPER, Move.PAPER), Outcome.TIE);
        assertOutcome(rps.getOutcome(Move.SCISSORS, Move.SCISSORS), Outcome.TIE);
    }
}