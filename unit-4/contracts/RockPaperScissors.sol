pragma solidity ^0.4.18;

import 'zeppelin-solidity/contracts/lifecycle/Pausable.sol';
import 'zeppelin-solidity/contracts/lifecycle/Destructible.sol';
import 'zeppelin-solidity/contracts/payment/PullPayment.sol';



contract RockPaperScissors is Pausable, Destructible, PullPayment {
    enum Move { Rock, Paper, Scissors }
    enum Status { None, Sender, Other, Both }

    event LogEnroll(address player1, address player2, uint value);
    event LogPayment(address player1, address player2, uint value, string reason);
    event LogPlay(address player1, address player2, bytes move);
    event LogReveal(address player1, address player2, uint move);

    mapping (bytes => uint) public games;
    mapping (bytes => uint) public secretMoves;
    mapping (bytes => uint) public moves;

    function RockPaperScissors() public {}

    // Enrollment
    function enroll(address with) external payable whenNotPaused returns (bool) {
        // non-zero enrollment
        require(msg.value > 0);
        bytes game = keccak256(msg.sender, with);
        // can't enroll twice
        require(games[game] == 0);
        games[game] = msg.value;
        LogEnroll(msg.sender, with, msg.value);
        return true;
    }

    function _getGame(address with) private view returns (bytes, bytes) {
        bytes game = keccak256(msg.sender, with);
        bytes otherGame = keccak256(with, msg.sender);
        return (game, otherGame);
    }

    function _getStatus(mapping (bytes => uint) map, bytes game, bytes otherGame) private view returns (uint, uint, Status) {
        uint value = map[game];
        uint otherValue = map[otherGame];
        if (value != 0 && otherValue != 0) {
            return (value, otherValue, Both);
        }
        if (value != 0 && otherValue == 0) {
            return (value, otherValue, Sender);
        }
        if (value == 0 && otherValue != 0) {
            return (value, otherValue, Other);
        }
        return (value, otherValue, None);
    }

    function hasEnrolled(address with) public whenNotPaused view returns (Status) {
        var (game, otherGame) = _getGame(with);
        var (, , status) = _getStatus(games, game, otherGame);
        return status;
    }

    function hasPlayed(address with) public whenNotPaused view returns (Status) {
        var (game, otherGame) = _getGame(with);
        var (, , status) = _getStatus(secretMoves, game, otherGame);
        return status;
    }

    function hasRevealed(address with) public whenNotPaused view returns (Status) {
        var (game, otherGame) = _getGame(with);
        var (, , status) = _getStatus(moves, game, otherGame);
        return status;
    }

    function cancel(address with) external whenNotPaused returns (bool) {
        // check other player hasn't enrolled
        var (game, otherGame) = _getGame(with);
        var (amount, , status) = _getStatus(games, game, otherGame);
        require(status == Sender);
        asyncSend(msg.send, amount);
        LogPayment(msg.sender, with, amount, 'cancel');
        return true;
    }

    function play(address with, bytes secretMove) external whenNotPaused returns (bool) {
        var (game, otherGame) = _getGame(with);
        var (, , enroll) = _getStatus(games, game, otherGame);
        require(enroll == Both);
        var (, , play) = _getStatus(secretMoves, game, otherGame);
        require(play == None || play == Other);
        secretMoves[game] = secretMove;
        LogPlay(msg.sender, with, secretMove);
        return true;
    }

    function reveal(address with, Move move, uint secret) external whenNotPaused returns (bool) {
        var (game, otherGame) = _getGame(with);
        var (, , enroll) = _getStatus(games, game, otherGame);
        require(enroll == Both);
        var (secretMove, , play) = _getStatus(secretMoves, game, otherGame);
        require(play == Both);
        var (, , reveal) = _getStatus(moves, game, otherGame);
        require(reveal == None || reveal == Other);
        require(secretMove == keccak256(move, secret));
        moves[game] = Move;
        LogReveal(msg.sender, with, Move);
        return true;
    }

    function rewardWinner(adddress with) external whenNotPaused returns (bool) {
        var (game, otherGame) = _getGame(with);
        var (, , enroll) = _getStatus(games, game, otherGame);
        require(enroll == Both);
        var (, , play) = _getStatus(secretMoves, game, otherGame);
        require(play == Both);
        var (move, otherMove, revealed) = _getStatus(moves, game, otherGame);
        if (revealed == Both) {
            // check who won
        }
        if (/* check timestamp*/) {
            asyncSend();
        }
        if () {
            asyncSend();
        }


    }
}