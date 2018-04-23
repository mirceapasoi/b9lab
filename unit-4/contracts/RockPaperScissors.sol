pragma solidity ^0.4.23;

import 'zeppelin-solidity/contracts/lifecycle/Pausable.sol';
import 'zeppelin-solidity/contracts/lifecycle/Destructible.sol';
import 'zeppelin-solidity/contracts/payment/PullPayment.sol';


contract RockPaperScissors is Pausable, Destructible, PullPayment {
    enum Move { NONE, ROCK, PAPER, SCISSORS }
    enum Status { NO_GAME, GAME_P1_WAITING, GAME_P1_DONE, GAME_P2_WAITING, GAME_P2_DONE }
    enum Outcome { TIE, WIN, LOSE, CANCEL }

    uint constant CANCEL_AFTER = 8 hours;

    event LogPayment(address indexed player1, address indexed player2, uint value, Outcome reason);
    event LogFirstMove(address indexed player1, address indexed player2, uint value, bytes32 move);
    event LogSecondMove(address indexed player1, address indexed player2, uint value, Move move);
    event LogFirstReveal(address indexed player1, address indexed player2, Move move);

    struct Game {
        Move move;
        uint32 updatedAt;
        uint value1;
        uint value2;
        bytes32 secretMove;
    }
    mapping (bytes32 => Game) public games;

    constructor() public {}

    // Called by player off-chain to hide their move
    function hashMove(address player1, address player2, Move move, bytes32 secret) public pure returns (bytes32) {
        return keccak256(player1, player2, move, secret);
    }

    function getGameKeys(address with) private view whenNotPaused returns (bytes32 key, bytes32 otherKey) {
        // Given two addresses A, B we hash "AB" as the key for "A wants to play with B",
        // and "BA" as the key for "B wants to play with A".
        // These keys are used for maintaining state in a mapping.
        key = keccak256(msg.sender, with);
        otherKey = keccak256(with, msg.sender);
    }

    function getGameStatus(address with) private view whenNotPaused returns (Game storage game, Status status) {
        bytes32 k1;
        bytes32 k2;
        (k1, k2) = getGameKeys(with);
        uint32 t1;
        uint32 t2;
        (t1, t2) = (games[k1].updatedAt, games[k2].updatedAt);
        // Both games can't exist at the same time
        assert(t1 == 0 || t2 == 0);
        if (t1 == 0 && t2 == 0) {
            // Default to sender as player 1 and return appropriate slot in storage
            game = games[k1];
            status = Status.NO_GAME;
        } else if (t1 != 0) {
            // Game started by sender as player 1
            game = games[k1];
            status = game.move != Move.NONE ? Status.GAME_P1_DONE : Status.GAME_P1_WAITING;

        } else if (t2 != 0) {
            // Game started by other, sender is player 2
            game = games[k2];
            status = game.move != Move.NONE ? Status.GAME_P2_DONE : Status.GAME_P2_WAITING;
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
        bytes32 k1;
        bytes32 k2;
        (k1, k2) = getGameKeys(with);
        delete games[k1];
        delete games[k2];
    }

    function _cancelGame(address with, uint v1, uint v2) private {
        if (v1 != 0) {
            asyncSend(msg.sender, v1);
            emit LogPayment(msg.sender, with, v1, Outcome.CANCEL);
        }
        if (v2 != 0) {
            asyncSend(with, v2);
            emit LogPayment(with, msg.sender, v2, Outcome.CANCEL);
        }
        _cleanGame(with);
    }

    function cancel(address with) external whenNotPaused {
        Game storage game;
        Status status;
        (game, status) = getGameStatus(with);
        require(status != Status.NO_GAME);
        if (status == Status.GAME_P1_WAITING) {
            // You're player 1, you've waited enough for player 2
            require(block.timestamp > game.updatedAt + CANCEL_AFTER);
            _cancelGame(with, game.value1, 0);
        } else if (status == Status.GAME_P1_DONE) {
            // You're player 1, you're foreiting the game to player 2
            require(block.timestamp > game.updatedAt + CANCEL_AFTER);
            _cancelGame(with, 0, game.value1 + game.value2);
        } else if (status == Status.GAME_P2_WAITING) {
            // You're player 2, you don't want to play, so player 1 gets his money back
            require(block.timestamp > game.updatedAt + CANCEL_AFTER);
            _cancelGame(with, 0, game.value1);
        } else if (status == Status.GAME_P2_DONE) {
            // You're player 2, you win because player 1 hasn't revelead
            require(block.timestamp > game.updatedAt + CANCEL_AFTER);
            _cancelGame(with, game.value1 + game.value2, 0);
        }
    }

    function playFirst(address with, bytes32 secretMove) external whenNotPaused payable {
        // don't play with yourself
        require(msg.sender != with);
        // non-zero play
        require(msg.value > 0);
        // Check game
        Game storage game;
        Status status;
        (game, status) = getGameStatus(with);
        require(status == Status.NO_GAME);
        // Sender plays in secret
        game.updatedAt = uint32(block.timestamp);
        game.value1 = msg.value;
        game.secretMove = secretMove;
        emit LogFirstMove(msg.sender, with, msg.value, secretMove);

    }

    function playSecond(address with, Move move) external whenNotPaused payable {
        // don't play with yourself
        require(msg.sender != with);
        // non-zero play
        require(msg.value > 0);
        // Check game
        Game storage game;
        Status status;
        (game, status) = getGameStatus(with);
        require(status == Status.GAME_P2_WAITING);
        // Sender plays in secret
        game.updatedAt = uint32(block.timestamp);
        game.value2 = msg.value;
        game.move = move;
        emit LogSecondMove(msg.sender, with, msg.value, move);
    }

    function revealFirst(address with, Move move, bytes32 secret) external whenNotPaused {
        Game storage game;
        Status status;
        (game, status) = getGameStatus(with);
        // Both must have played
        require(status == Status.GAME_P1_DONE);
        // Move must match secret move
        require(hashMove(msg.sender, with, move, secret) == game.secretMove);
        emit LogFirstReveal(msg.sender, with, move);
        Outcome outcome = getOutcome(move, game.move);
        uint total = game.value1 + game.value2;
        if (outcome == Outcome.WIN) {
            asyncSend(msg.sender, total);
            emit LogPayment(msg.sender, with, total, outcome);
        } else if (outcome == Outcome.LOSE) {
            asyncSend(with, total);
            emit LogPayment(with, msg.sender, total, outcome);
        } else {
            asyncSend(msg.sender, game.value1);
            asyncSend(with, game.value2);
            emit LogPayment(msg.sender, with, game.value1, outcome);
            emit LogPayment(with, msg.sender, game.value2, outcome);
        }
        // Clean-up
        _cleanGame(with);
    }
}