'use strict';
angular.module('JungleJingleApp', ['firebase', 'hmTouchEvents']).config([
  '$locationProvider', function($locationProvider) {
    return $locationProvider.html5Mode(true).hashPrefix('');
  }
]).value('firebaseUrl', 'http://madebymark.firebaseio.com/junglejingle/').factory('generateCode', [
  '$location', function($location) {
    return function() {
      var consonants, pick, vowels;
      vowels = "aeuio";
      consonants = "bcdfghklmnprstvxz";
      pick = function(letters) {
        return letters[Math.floor(Math.random() * letters.length)];
      };
      return pick(vowels) + pick(consonants) + pick(vowels) + pick(consonants) + pick(vowels);
    };
  }
]).factory('playerId', function() {
  return Math.random().toString(36).substring(2);
}).controller('AppCtrl', [
  '$scope', '$location', '$q', 'firebaseUrl', 'playerId', 'generateCode', 'angularFire', function($scope, $location, $q, firebaseUrl, playerId, generateCode, angularFire) {
    var code;
    $scope.code = code = (function() {
      code = $location.path().substr(1);
      if (!code) {
        code = generateCode();
        $location.path(code).replace();
      }
      return code;
    })();
    $scope.newCode = generateCode();
    $scope.url = $location.absUrl();
    $scope.connection = function() {
      return "loading";
    };
    $scope.me = "loading";
    return (function() {
      var aBind, aRef, bBind, bRef;
      aRef = new Firebase(firebaseUrl + code + "/a");
      bRef = new Firebase(firebaseUrl + code + "/b");
      aBind = angularFire(aRef, $scope, 'playera', 'loading');
      bBind = angularFire(bRef, $scope, 'playerb', 'loading');
      return $q.all([aBind, bBind]).then(function() {
        return $scope.connection = function() {
          var a, b;
          a = $scope.playera;
          b = $scope.playerb;
          if (playerId === a || playerId === b) {
            if (a && b) {
              return "playing";
            } else {
              return "waiting";
            }
          } else if (!a) {
            $scope.me = 'a';
            $scope.playera = playerId;
            aRef.onDisconnect().remove();
            if (b) {
              return "playing";
            } else {
              return "waiting";
            }
          } else if (!b) {
            $scope.me = 'b';
            $scope.playerb = playerId;
            bRef.onDisconnect().remove();
            if (a) {
              return "playing";
            } else {
              return "waiting";
            }
          } else {
            return "watching";
          }
        };
      });
    })();
  }
]).factory('isWinner', [
  function() {
    var xWinsFromY;
    xWinsFromY = {
      'elephant': {
        'lion': true,
        'snake': true
      },
      'lion': {
        'snake': true,
        'mouse': true
      },
      'snake': {
        'mouse': true,
        'fence': true
      },
      'mouse': {
        'fence': true,
        'elephant': true
      },
      'fence': {
        'elephant': true,
        'lion': true
      }
    };
    return function(myMove, opponentMove) {
      return (xWinsFromY[myMove][opponentMove] != null) || myMove === opponentMove || !opponentMove;
    };
  }
]).controller('GameCtrl', [
  '$scope', 'isWinner', 'firebaseUrl', 'angularFire', function($scope, isWinner, firebaseUrl, angularFire) {
    var code, lose, me, moveBind, other;
    $scope.animals = ['elephant', 'lion', 'snake', 'mouse', 'fence'];
    $scope.me = me = $scope.$parent.me;
    $scope.other = other = {
      'a': 'b',
      'b': 'a'
    }[me];
    code = $scope.$parent.code;
    $scope.moves = [];
    moveBind = angularFire(new Firebase(firebaseUrl + code + '/moves'), $scope, 'moves', []);
    moveBind.then(function() {
      var _ref;
      if (!((_ref = $scope.moves) != null ? _ref.length : void 0)) {
        return $scope.moves = [];
      }
    });
    $scope.myScore = 0;
    angularFire(new Firebase(firebaseUrl + code + "/score/" + me), $scope, 'myScore', 0);
    $scope.opponentScore = 0;
    angularFire(new Firebase(firebaseUrl + code + "/score/" + other), $scope, 'opponentScore', 0);
    $scope.selectMove = function(myMove) {
      var opponentMove;
      if ($scope.isMyTurn()) {
        $scope.moves.push(myMove);
        opponentMove = $scope.getOpponentMove();
        if (!opponentMove) {

        } else if (myMove === opponentMove) {

        } else if (!isWinner(myMove, opponentMove)) {
          return lose();
        }
      }
    };
    lose = function() {
      return $scope.opponentScore++;
    };
    $scope.getOpponentMove = function() {
      var len, _ref;
      len = ((_ref = $scope.moves) != null ? _ref.length : void 0) || 0;
      if ($scope.isMyTurn() && len > 0) {
        return $scope.moves[len - 1];
      } else if (len >= 2) {
        return $scope.moves[len - 2];
      }
    };
    $scope.getMyMove = function() {
      if (!$scope.isMyTurn()) {
        return $scope.moves[$scope.moves.length - 1];
      }
    };
    return $scope.isMyTurn = function() {
      var len;
      len = $scope.moves.length || 0;
      if (me === 'a') {
        return len % 2 === 0;
      } else if (me === 'b') {
        return len % 2 === 1;
      } else {
        return false;
      }
    };
  }
]).run([
  '$rootScope', function($rootScope) {
    return $rootScope.safeApply = function(fn) {
      var phase;
      phase = this.$root.$$phase;
      if (phase === '$apply' || phase === '$digest') {
        if (fn && (typeof fn === 'function')) {
          return fn();
        }
      } else {
        return this.$apply(fn);
      }
    };
  }
]);
;
//# sourceMappingURL=app.js.map