pragma solidity ^0.5.0;
import "hardhat/console.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v2.3.0/contracts/math/SafeMath.sol";
pragma experimental ABIEncoderV2;

contract MyContract {
    using SafeMath for uint;
    enum ContractState {Active, Suspended}
    enum State {Available, Rented, Damaged, UnderRepair, NotReturned, Locked, Inspection}
    State[] statearray = [State.Available, State.Rented, State.Damaged, State.UnderRepair, State.NotReturned, State.Locked, State.Inspection];
    string[] statename = ["Available", "Rented", "Damaged", "UnderRepair", "NotReturned", "Locked", "Inspection"];
    
    address payable wallet;
    ContractState public currentcontractstate;
    uint  totalcost;
    uint  carinrentalprocess;
    uint currentamountpaid;
    uint mulresult;

    
    struct Car {
        uint _id;
        string _model;
        uint _rentalprice;
        uint _depositfee;
        State _carstate;
        address payable _currentOwner;
    }

    Car[] carlist;

    constructor(address payable _wallet) public {
        wallet = _wallet;
        currentcontractstate = ContractState.Active;
        carlist.push(Car(0, "Tesla", 7, 14, State.Available, _wallet));
        carlist.push(Car(1, "Benz", 15, 30, State.Available, _wallet));
        carlist.push(Car(2, "BMW", 10, 20, State.UnderRepair, _wallet));
    }

    // check car availability
    modifier rentcheck(uint _id) {
        require(carlist[_id]._carstate == State.Available, "This car is currently not availble for rental");
        _;
    }
    
    // check car rented
    modifier returncheck(uint _id) {
        require(carlist[_id]._carstate == State.Rented, "This car is not rented out");
        _;
    }


    // check company
    modifier isCompany (address user) {
        require(wallet == user, "This function can only be called by ABC Rental Company");
        _;
    }

    // check car damaged
    modifier damagecheck(uint _id) {
        require(carlist[_id]._carstate == State.Damaged, "This car is not damaged");
        _;
    }

    // check car under repair
    modifier repaircheck(uint _id) {
        require(carlist[_id]._carstate == State.UnderRepair, "This car is not under repair");
        _;
    }
  
    modifier isactive (){
        require(currentcontractstate == ContractState.Active, "This contract is currently suspended");
        _;
    }

    // 
    modifier confirmpaymentcheck(uint accumulatedamount, uint cost) {
        console.log("The remaining amount yet to pay:", cost-accumulatedamount/1000000000000000000);
        require(accumulatedamount/1000000000000000000 >= cost, "The amount you have transfered is not enough");
        _;
    }

    modifier Conditioncheck (uint _id){
        require(carlist[_id]._carstate == State.Inspection || carlist[_id]._carstate == State.NotReturned, "This car is neither in inspection status nor not returned status");
        _;
    }

    modifier isPositive (uint number){
        require(number > 0, "Cannot rent for 0 day");
        _;
    }

    function listCar() public view returns(Car[] memory){
        for(uint i=0; i<carlist.length; i++){
            console.log("Car id:", carlist[i]._id);
            console.log("Car model:", carlist[i]._model);
            console.log("Rental price per day:", carlist[i]._rentalprice);
            console.log("Deposit fee:", carlist[i]._depositfee);
            console.log("Current Status:", statename[uint(carlist[i]._carstate)]);
        }
        
        return carlist;
    }

    function addCar(string memory _model, uint _rentalprice, uint _depositfee, uint _state) 
    public isCompany(msg.sender){
        carlist.push(Car(carlist.length, _model, _rentalprice, _depositfee, statearray[_state], wallet));
    }

    function removeCar(uint _id)
    public isCompany(msg.sender){
        carlist[_id] = carlist[carlist.length-1];
        carlist[_id]._id = _id;
        carlist.pop();
    }

    function showCarStatus(uint _id)
    view public returns(string memory){
        return statename[uint(carlist[_id]._carstate)];
    }

    function showTotalCost(uint _id, uint rentalDays)
    view public isPositive(rentalDays) returns(uint){
        
        SafeMath.add(SafeMath.mul(carlist[_id]._rentalprice, rentalDays),carlist[_id]._depositfee);
        // safeAdd(mulresult,carlist[_id]._depositfee);
        //return carlist[_id]._rentalprice*rentalDays+carlist[_id]._depositfee;
    }

    function rentcar(uint _id, uint rentalDays) 
    public isactive() rentcheck(_id) isPositive(rentalDays){
        totalcost = showTotalCost(_id, rentalDays);
        carinrentalprocess = _id;
        carlist[_id]._carstate = State.Locked;
        currentamountpaid = 0;
        console.log("The total cost is", totalcost, ", please proceed to payment.");
    }

    function makepayment() public payable{
        currentamountpaid = SafeMath.add(currentamountpaid,msg.value);
        //currentamountpaid += msg.value;
    }

    function confirmPayment() 
    public confirmpaymentcheck(currentamountpaid, totalcost) {
        carlist[carinrentalprocess]._carstate = State.Rented;
        carlist[carinrentalprocess]._currentOwner = msg.sender;
        console.log("Finish Payment, Thank you.");
        wallet.transfer(currentamountpaid-carlist[carinrentalprocess]._depositfee*1000000000000000000);
        carinrentalprocess = 0;
        totalcost = 0;
    }

    function returncar(uint _id) 
    public returncheck(_id) 
    returns(uint){
        carlist[_id]._carstate = State.Inspection;
        carlist[_id]._currentOwner = wallet;
        console.log("Car", _id, "is returned and pending a mechanic to conduct an inspection of car condition.");
    }

    // assumes maintenanceexpense will not exceed deposite amount
    function checkCondition(uint _id, bool _damage, uint maintenanceexpense) 
    public Conditioncheck(_id){
        if (carlist[_id]._carstate == State.NotReturned){
            takeDeposit(_id, carlist[_id]._depositfee);
        } else if(_damage){
            carlist[_id]._carstate = State.Damaged;
            takeDeposit(_id, maintenanceexpense);
        } else{
            returnDeposit(_id);
        }
    }

    function takeDeposit(uint _id, uint nonrefundableamount) 
    public {
        carlist[_id]._currentOwner.transfer(carlist[_id]._depositfee*1000000000000000000-nonrefundableamount);
        console.log("Take Deposit", _id, nonrefundableamount);
    }

    function returnDeposit(uint _id) public {
        carlist[_id]._currentOwner.transfer(carlist[_id]._depositfee*1000000000000000000);
        console.log("Return Deposit", _id);
    }
    
    function sendRepair(uint _id) 
    public damagecheck(_id){
        carlist[_id]._carstate = State.UnderRepair;
        console.log("Car", _id, "is under repair.");
    }


    function repairDone(uint _id) 
    public repaircheck(_id){
        carlist[_id]._carstate = State.Available;
        console.log("Repair done. Car", _id, "is available.");
    }


    function carNotReturned(uint _id) 
    public returncheck(_id) isCompany(msg.sender){
        if (carlist[_id]._carstate != State.Available){
            carlist[_id]._carstate = State.NotReturned;
            console.log("Not return", _id,"The car is not returned after the rental period");
        }
    }

    function suspend()
    public isCompany(msg.sender){ 
    currentcontractstate == ContractState.Suspended;
    console.log("Suspend", "The contract is suspended");
    }

    function activate()
    public isCompany(msg.sender){ 
    currentcontractstate == ContractState.Active;
    console.log("Activate","The contract is activated");
    }

}
