
// Version de solidity del Smart Contract
// SPDX-License-Identifier: UNLICENSED

pragma solidity >=0.4.22 <0.9.0;

// Informacion del Smart Contract
// Nombre: Lottery
// Logica: Implementa una loteria entre un numero indefinido de participantes, la loteria acaba cuando se agote el tiempo pasado por parametro en segundos

contract Lottery{

address payable [] public gamblers;
address payable public winner ;
bool private activeContract;
uint balance;
uint public secondsToEnd;
uint public createdTime;
address public owner;

uint public bid;

event Status(string _message);
event Result(string _message, address winner);

//pasamos por parametro el valor del precio de entrada y el tiempo que va a durar activa
constructor (uint _bid, uint _time) public{

    bid=_bid;
    owner = msg.sender;
    activeContract = true;
    balance=0;
    secondsToEnd = _time;
    createdTime = block.timestamp;
}

//en esta funcion vamos llenando el array hasta que se acabe el tiempo
function  bidLottery() public payable{

    if ( block.timestamp < (createdTime + secondsToEnd) && activeContract==true){
        require(msg.value == bid);
        gamblers.push(payable(msg.sender));
        balance += msg.value;
    }   
    else{
        payable(msg.sender).transfer(msg.value);
        emit Status("Se han cerrado las apuestas, fin de tiempo");
        selectWinner();
        activeContract=false;
    }
}

//Seleccionamos el ganador y lo notificamos
function selectWinner() public payable{
    uint index=random()%gamblers.length;
    winner = gamblers[index];
    winner.transfer(balance);
    emit Result("El ganador es:", winner);
}

//Aqui generamos un numero pseudo aleatorio para elegir el ganador
  function random() private view returns (uint) {
        return uint(keccak256(abi.encodePacked(block.difficulty, block.timestamp, gamblers)));  
    }

//Aqui sacamos los segundos para acabar
    function  _timeToEnd() public view returns (uint){
        return secondsToEnd-(block.timestamp-createdTime);
    }
//Aqui podemos ver el numero de participantes
    function numGamblers() public view returns(uint){
        return gamblers.length;
    }

//parar loteria
    function stopLottery() public payable{
        require(msg.sender==owner, "Debes ser el owner del contrato");
        activeContract=false;
        emit Status("Loteria parada, devueltos los fondos");
        for(uint i =0; i<gamblers.length ;i++){
            gamblers[i].transfer(balance/gamblers.length);
        }
    }
}