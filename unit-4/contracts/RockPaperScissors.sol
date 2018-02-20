pragma solidity ^0.4.18;

import 'zeppelin-solidity/contracts/lifecycle/Pausable.sol';
import 'zeppelin-solidity/contracts/lifecycle/Destructible.sol';
import 'zeppelin-solidity/contracts/payment/PullPayment.sol';


contract RockPaperScissors is Pausable, Destructible, PullPayment {
    enum Move { NONE, ROCK, PAPER, SCISSORS }
    enum Status { NONE, SENDER, OTHER, BOTH }
    enum Outcome { TIE, WIN, LOSE }

    uint constant CANCEL_AFTER = 1 hours;
    uint constant FORFEIT_AFTER = 8 hours;

    event LogEnroll(address player1, address player2, uint value);
    event LogPayment(address player1, address player2, uint value, string reason);
    event LogPlay(address player1, address player2, bytes32 move);
    event LogReveal(address player1, address player2, Move move);

    struct Game {
        uint time;
        uint value;
        bytes32 secretMove;
        Move move;
    }
    mapping (bytes32 => Game) public games;

    function RockPaperScissors() public {}

    // Enrollment
    function enroll(address with) external payable whenNotPaused returns (bool) {
        // non-zero enrollment
        require(msg.value > 0);
        bytes32 game = keccak256(msg.sender, with);
        // can't enroll twice
        require(games[game].time == 0);
        games[game] = Game(block.timestamp, msg.value, 0, Move.NONE);
        LogEnroll(msg.sender, with, msg.value);
        return true;
    }

    function getGameKeys(address with) public view whenNotPaused returns (bytes32, bytes32) {
        // Given two addresses A, B we hash "AB" as the key for "A wants to play with B",
        // and "BA" as the key for "B wants to play with A".
        // These keys are used for maintaining state in a mapping.
        bytes32 key = keccak256(msg.sender, with);
        bytes32 otherKey = keccak256(with, msg.sender);
        return (key, otherKey);
    }

    function getGameStatus(address with) public view whenNotPaused returns (bytes32 key, bytes32 otherKey, Status enrolled, Status played, Status revealed) {
        var (k1, k2) = getGameKeys(with);
        key = k1;
        otherKey = k2;
        // Enrollment
        var (g1, g2) = (games[k1].time, games[k2].time);
        enrolled = g1 != 0 && g2 != 0 ? Status.BOTH : (g1 != 0 ? Status.SENDER : (g2 != 0 ? Status.OTHER : Status.NONE));
        // Secret play
        if (enrolled == Status.BOTH) {
            var (s1, s2) = (games[k1].secretMove, games[k2].secretMove);
            played = s1 != 0 && s2 != 0 ? Status.BOTH : (s1 != 0 ? Status.SENDER : (s2 != 0 ? Status.OTHER : Status.NONE));
        } else {
            played = Status.NONE;
        }
        // Revelead play
        if (played == Status.BOTH) {
            var (m1, m2) = (uint(games[k1].move), uint(games[k2].move));
            revealed = m1 != 0 && m2 != 0 ? Status.BOTH : (m1 != 0 ? Status.SENDER : (m2 != 0 ? Status.OTHER : Status.NONE));
        } else {
            revealed = Status.NONE;
        }
    }

    function _cleanGame(address with) private {
        var (key, otherKey) = getGameKeys(with);
        delete games[key];
        delete games[otherKey];
    }

    function _getOutcome(Move move, Move otherMove) private pure returns (Outcome) {
        if (move == Move.NONE)
            return Outcome.LOSE;
        if (otherMove == Move.NONE)
            return Outcome.WIN;
        if (move == otherMove)
            return Outcome.TIE;
        if (move == Move.ROCK)
            return otherMove != Move.PAPER ? Outcome.WIN : Outcome.LOSE;
        if (move == Move.PAPER)
            return otherMove != Move.SCISSORS ? Outcome.WIN : Outcome.LOSE;
        // Scissors
        return otherMove != Move.ROCK ? Outcome.WIN : Outcome.LOSE;
    }


    function cancel(address with) external whenNotPaused returns (bool) {
        var (key, , enrolled, , ,) = getGameStatus(with);
        // Sender is the only one who enrolled i.e. other player hasn't enrolled
        require(enrolled == Status.SENDER);
        // Lock funds for at least 1 hour
        require(block.timestamp > games[key].time + CANCEL_AFTER);
        // Return funds
        uint value = games[key].value;
        asyncSend(msg.sender, value);
        LogPayment(msg.sender, with, value, "cancel");
        return true;
    }

    function play(address with, bytes32 secretMove) external whenNotPaused returns (bool) {
        var (key, , enrolled, played, ,) = getGameStatus(with);
        // Both must be enrolled
        require(enrolled == Status.BOTH);
        // Sender hasn't played before + other player has played or not
        require(played == Status.NONE || played == Status.OTHER);
        // Sender plays in secret
        games[key].secretMove = secretMove;
        LogPlay(msg.sender, with, secretMove);
        return true;
    }

    function test(address with) external view returns (bytes32) {
        var (key, ) = getGameKeys(with);
        return games[key].secretMove;
    }

    function reveal(address with, Move move, string secret) external whenNotPaused returns (bool) {
        var (key, , enrolled, played, revealed) = getGameStatus(with);
        // Both must be enrolled
        require(enrolled == Status.BOTH);
        // Both must have played secretly
        require(played == Status.BOTH);
        // Sender hasn't revealed before + other player has revelead or not
        require(revealed == Status.NONE || revealed == Status.OTHER);
        // Sender reveals
        require(games[key].secretMove == keccak256(move, secret));
        games[key].move = move;
        LogReveal(msg.sender, with, move);
        return true;
    }

    function rewardWinner(address with) external whenNotPaused returns (Outcome) {
        var (key, otherKey, enrolled, played, revealed) = getGameStatus(with);
        // Both must be enrolled
        require(enrolled == Status.BOTH);
        // Both must have played secretly
        require(played == Status.BOTH);
        if (revealed != Status.BOTH) {
            // Make sure enough time has elapsed to make a decision i.e.
            // maximum of both enrollment times + a few hours
            var cutoff = (games[key].time > games[otherKey].time ? games[key].time : games[otherKey].time) + FORFEIT_AFTER;
            require(block.timestamp > cutoff);
        }
        var outcome = _getOutcome(games[key].move, games[otherKey].move);
        uint total = games[key].value + games[otherKey].value;
        if (outcome == Outcome.WIN) {
            asyncSend(msg.sender, total);
            LogPayment(msg.sender, with, total, "win");
        } else if (outcome == Outcome.LOSE) {
            asyncSend(with, total);
            LogPayment(msg.sender, with, total, "lose");
        } else {
            var (v1, v2) = (games[key].value, games[otherKey].value);
            asyncSend(msg.sender, v1);
            asyncSend(with, v2);
            LogPayment(msg.sender, with, v1, "tie");
            LogPayment(with, msg.sender, v2, "tie");
        }
        // Clean-up
        _cleanGame(with);
        return outcome;
    }
}