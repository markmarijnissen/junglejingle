'use strict'

# define Jungle Jingle App module
angular
.module('JungleJingleApp',[
  'firebase'              # firebase for sync
  'hmTouchEvents'         # hammer touch events
  #'LocalStorageModule'   # local storage
  #'ngSanitize'           # sanitize
])
# howler & jQuery are also included

# config app
.config([
  '$locationProvider',
  ($locationProvider) ->
    $locationProvider.html5Mode(true).hashPrefix('');
])

# define firebase base URL
.value('firebaseUrl','http://madebymark.firebaseio.com/junglejingle/')

# factory to generate game code
.factory('generateCode',[ 
  '$location',
  ($location) -> ->
    vowels = "aeuio"
    consonants = "bcdfghklmnprstvxz"
    pick = (letters) -> letters[Math.floor(Math.random() * letters.length)]
    pick(vowels)+pick(consonants)+pick(vowels)+pick(consonants)+pick(vowels)
])

# unique ID to count number of players in a game
.factory('playerId', -> Math.random().toString(36).substring(2);)

# main app controller; responsible for maintaining connection and home screens
.controller('AppCtrl',[
  '$scope','$location','$q','firebaseUrl','playerId','generateCode','angularFire',
  ($scope,  $location,  $q , firebaseUrl,  playerId,  generateCode,  angularFire) ->
    
    # set the code
    $scope.code = code = do ->
      # retrieve from path
      code = $location.path().substr(1)
      #.... or generate a new one
      if not code
        code = generateCode()
        $location.path(code).replace() # and update location
      code

    # if this game is already occupied
    $scope.newCode = generateCode()
    # use this URL to let a friend join
    $scope.url = $location.absUrl();

    # connect to firebase to retrieve playerA/B status    
    $scope.connection = -> "loading"  
    $scope.me = "loading"
    do ->
      # create playerA and playerB firebase
      aRef = new Firebase(firebaseUrl+code+"/a")
      bRef = new Firebase(firebaseUrl+code+"/b")
      # link them to the scope
      aBind = angularFire(aRef,$scope,'playera','loading')
      bBind = angularFire(bRef,$scope,'playerb','loading')
      # when they are loaded, update the "connection" function
      $q.all([aBind,bBind]).then -> 
        $scope.connection = ->
            a = $scope.playera
            b = $scope.playerb
            # if you're in the game, either play or wait
            if playerId in [a,b]
              if a and b then "playing" else "waiting"
            # if you're not in the game, try to join as 'a'
            else if not a
              $scope.me = 'a'
              $scope.playera = playerId 
              aRef.onDisconnect().remove() # free spot on disconnect
              if b then "playing" else "waiting"
            # if you're not in the game, try to join as 'b'
            else if not b
              $scope.me = 'b'
              $scope.playerb = playerId
              bRef.onDisconnect().remove()
              if a then "playing" else "waiting"
            # both places are occupied, you're waiting for a spot
            else
              "watching"

])

.factory('isWinner',[
  -> 
    # hashmap that defines "winners" as true;
    # losers are undefined.
    xWinsFromY = 
      'elephant':
        'lion': true
        'snake': true
      'lion':
        'snake': true
        'mouse': true
      'snake':
        'mouse':true
        'fence':true
      'mouse':
        'fence':true
        'elephant':true    
      'fence':
        'elephant':true
        'lion':true
    (myMove,opponentMove) -> 
      xWinsFromY[myMove][opponentMove]? or myMove is opponentMove or not opponentMove
])

# game controller; responsible for in-game dynamics
.controller('GameCtrl',[
  '$scope','isWinner','firebaseUrl','angularFire',
  ($scope,  isWinner,  firebaseUrl,  angularFire) ->

    # animals
    $scope.animals = ['elephant','lion','snake','mouse','fence'];

    # inherit 'me' and 'code' from the parent 'App' scope
    $scope.me = me = $scope.$parent.me
    $scope.other = other = {'a':'b','b':'a'}[me];
    code = $scope.$parent.code

    # firebase keeps track of a chain of moves;
    # player A has all 'even' moves (0,2,4,..)
    # player B haas all 'uneven' moves (1,3,5,..)
    $scope.moves = []
    moveBind = angularFire(new Firebase(firebaseUrl+code+'/moves'),$scope,'moves',[])
    moveBind.then ->
      # if firebase sets 'moves' to null (doesn't exist), initialize!
      if not $scope.moves?.length then $scope.moves = []

    #firebase keeps track of score
    $scope.myScore = 0
    angularFire(new Firebase(firebaseUrl+code+"/score/"+me),$scope,'myScore',0)
    $scope.opponentScore = 0;
    angularFire(new Firebase(firebaseUrl+code+"/score/"+other),$scope,'opponentScore',0)

    # make move
    $scope.selectMove = (myMove) -> 
      if $scope.isMyTurn()  
        # add move to Firebase
        $scope.moves.push(myMove)
        opponentMove = $scope.getOpponentMove()
        if not opponentMove
          # first move
        else if myMove is opponentMove
          # same; they fall in love
        else if not isWinner(myMove,opponentMove) 
          lose()

    lose = ->
      $scope.opponentScore++
      # buzz  

    # get move from opponent
    # if my turn; it's last move (a wild .... appears)
    # if NOT my turn; it's second last move (a wild ... appears)
    $scope.getOpponentMove = ->
      len = $scope.moves?.length or 0
      # if my turn, I haven't moved, so other move is last
      if $scope.isMyTurn() and len > 0 
        $scope.moves[len-1]
      # if NOT my turn, then I have moved, so other move is second last
      else if len >= 2 
        $scope.moves[len-2]

    # get my move; 
    # if my turn; it's blank (i have to choose)
    # if NOT my turn; then it's on screen (as response)
    $scope.getMyMove = ->
      if not $scope.isMyTurn() then $scope.moves[$scope.moves.length-1]

    # helper method
    $scope.isMyTurn = ->
      len = $scope.moves.length or 0
      if me is 'a'
        len % 2 == 0
      else if me is 'b'
        len % 2 == 1
      else
        false # game is initalizing...

])

.run([
  '$rootScope',
  ($rootScope) ->
    $rootScope.safeApply = (fn) -> 
      phase = this.$root.$$phase
      if(phase == '$apply' || phase == '$digest') 
        if(fn && (typeof(fn) == 'function')) 
          fn()
      else 
        @$apply(fn)
])

