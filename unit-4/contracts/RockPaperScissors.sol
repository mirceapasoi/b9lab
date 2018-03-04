pragma solidity ^0.4.18;

import 'zeppelin-solidity/contracts/lifecycle/Pausable.sol';
import 'zeppelin-solidity/contracts/lifecycle/Destructible.sol';
import 'zeppelin-solidity/contracts/payment/PullPayment.sol';


contract RockPaperScissors is Pausable, Destructible, PullPayment {
    enum Move { NONE, ROCK, PAPER, SCISSORS }
    enum Status { NONE, SENDER, OTHER, BOTH }
    enum Outcome { TIE, WIN, LOSE, CANCEL }

    uint constant CANCEL_AFTER = 8 hours;

    event LogPayment(address indexed player1, address indexed player2, uint value, Outcome reason);
    event LogPlay(address indexed player1, address indexed player2, bytes32 move);
    event LogReveal(address indexed player1, address indexed player2, Move indexed move);

    struct Game {
        Move move;
        uint32 updatedAt;
        uint value;
        bytes32 secretMove;
    }
    mapping (bytes32 => Game) public games;

    function RockPaperScissors() public {}

    // Called by player off-chain to hide their move
    function hashMove(address player1, address player2, Move move, bytes32 secret) public pure returns (bytes32) {
        return keccak256(player1, player2, move, secret);
    }

    function getGameKeys(address with) private view whenNotPaused returns (bytes32, bytes32) {
        // Given two addresses A, B we hash "AB" as the key for "A wants to play with B",
        // and "BA" as the key for "B wants to play with A".
        // These keys are used for maintaining state in a mapping.
        bytes32 key = keccak256(msg.sender, with);
        bytes32 otherKey = keccak256(with, msg.sender);
        return (key, otherKey);
    }

    function getGameStatus(address with) private view whenNotPaused returns (Game storage g1, Game storage g2, Status played, Status revealed) {
        var (k1, k2) = getGameKeys(with);
        g1 = games[k1];
        g2 = games[k2];
        // Secret play
        bytes32 s1 = g1.secretMove;
        bytes32 s2 = g2.secretMove;
        played = s1 != 0 && s2 != 0 ? Status.BOTH : (s1 != 0 ? Status.SENDER : (s2 != 0 ? Status.OTHER : Status.NONE));
        // Revelead play
        if (played == Status.BOTH) {
            uint8 m1 = uint8(g1.move);
            uint8 m2 = uint8(g2.move);
            revealed = m1 != 0 && m2 != 0 ? Status.BOTH : (m1 != 0 ? Status.SENDER : (m2 != 0 ? Status.OTHER : Status.NONE));
        } else {
            revealed = Status.NONE;
        }
    }

    function getOutcome(Move move, Move otherMove) public pure returns (Outcome) {
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

    function _cleanGame(address with) private {
        var (k1, k2) = getGameKeys(with);
        delete games[k1];
        delete games[k2];
    }

    function _cancelGame(address with, uint v1, uint v2) private {
        if (v1 != 0) {
            asyncSend(msg.sender, v1);
            LogPayment(msg.sender, with, v1, Outcome.CANCEL);
        }
        if (v2 != 0) {
            asyncSend(with, v2);
            LogPayment(with, msg.sender, v2, Outcome.CANCEL);
        }
        _cleanGame(with);
    }

    function cancel(address with) external whenNotPaused {
        var (game, otherGame, played, revealed) = getGameStatus(with);
        // If game is done, one of the players should call rewardWinner()
        require(played != Status.BOTH || revealed != Status.BOTH);
        // Can't cancel if you didn't play in the game
        require(played == Status.SENDER || played == Status.BOTH);
        // Game data
        uint32 t1 = game.updatedAt;
        uint v1 = game.value;
        // Sender is the only one who played i.e. other player hasn't played
        if (played == Status.SENDER) {
            // Lock funds for at least 8 hour
            require(block.timestamp > t1 + CANCEL_AFTER);
            // Return funds
            _cancelGame(with, v1, 0);
        } else {
            uint32 t2 = otherGame.updatedAt;
            uint v2 = otherGame.value;
            // Both have played - lock funds for at least 8 hour
            require(block.timestamp > (t1 > t2 ? t1 : t2) + CANCEL_AFTER);
            if (revealed == Status.NONE) {
                // both get money back
                _cancelGame(with, v1, v2);
            } else if (revealed == Status.SENDER) {
                // sender gets all the money
                _cancelGame(with, v1 + v2, 0);
            } else if (revealed == Status.OTHER) {
                // other gets all the money
                _cancelGame(with, 0, v1 + v2);
            }
        }
    }

    function play(address with, bytes32 secretMove) external whenNotPaused payable {
        // don't play with yourself
        require(msg.sender != with);
        // non-zero play
        require(msg.value > 0);
        // Check game
        var (game, , played, ,) = getGameStatus(with);
        // Sender hasn't played before + other player has played or not
        require(played == Status.NONE || played == Status.OTHER);
        // Sender hasn't played this move before
        // Sender plays in secret
        game.updatedAt = uint32(block.timestamp);
        game.value = msg.value;
        game.secretMove = secretMove;
        LogPlay(msg.sender, with, secretMove);
    }

    function reveal(address with, Move move, bytes32 secret) external whenNotPaused {
        var (game, , played, revealed) = getGameStatus(with);
        // Both must have played secretly
        require(played == Status.BOTH);
        // Sender hasn't revealed before + other player has revelead or not
        require(revealed == Status.NONE || revealed == Status.OTHER);
        // Sender reveals
        require(game.secretMove == hashMove(msg.sender, with, move, secret));
        game.move = move;
        game.updatedAt = uint32(block.timestamp);
        LogReveal(msg.sender, with, move);
    }

    function rewardWinner(address with) external whenNotPaused {
        var (game, otherGame, played, revealed) = getGameStatus(with);
        // Both must have played secretly
        require(played == Status.BOTH);
        // Both must have revealed
        require(revealed == Status.BOTH);
        Outcome outcome = getOutcome(game.move, otherGame.move);
        uint total = game.value + otherGame.value;
        if (outcome == Outcome.WIN) {
            asyncSend(msg.sender, total);
            LogPayment(msg.sender, with, total, outcome);
        } else if (outcome == Outcome.LOSE) {
            asyncSend(with, total);
            LogPayment(with, msg.sender, total, outcome);
        } else {
            uint v1 = game.value;
            uint v2 = otherGame.value;
            asyncSend(msg.sender, v1);
            asyncSend(with, v2);
            LogPayment(msg.sender, with, v1, outcome);
            LogPayment(with, msg.sender, v2, outcome);
        }
        // Clean-up
        _cleanGame(with);
    }
}