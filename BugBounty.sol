/*
Copyright 2016 Marek Laskowski

   Licensed under the Apache License, Version 2.0 (the "License");
   you may not use this file except in compliance with the License.
   You may obtain a copy of the License at

       http://www.apache.org/licenses/LICENSE-2.0

   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License.
*/
pragma solidity ^0.4.4;

contract BugBounty{
    uint constant minGas = 500000; //TODO: set this by provider?
    address private provider;//contract provider -  this is contract owner
    address private sponsor;//paying for the bounty
    string private description;

    /*
    the developer that submits required code will recieve 
    devPctNumertor * value / devPctDenominator
    */
    uint8 private devPctNumerator;
    uint8 private devPctDenominator;
    
    /*
    track who has gotten paid
    */
    bool developerWasPaid;
    bool validatorWasPaid;
    
    /*
    compute and store the amount going to the developer and validator
    */
    uint developerBounty;
    uint validatorBounty;
    
    
    mapping(address => uint) private validators;
    
    bool private mutex;
    
    modifier sufficientGas{
        if(msg.gas < minGas) throw;
        _;
    }
    
    modifier positiveValue{
        if (msg.value == 0) throw;
        _;
    }
    
    modifier onlySponsor{
        if(msg.sender != sponsor) throw;
        _;
    }
    
    modifier onlyProvider{
        if(msg.sender != provider) throw;
        _;
    }
    
    modifier onlyValidator{
        if(validators[msg.sender] != 1) throw;
        _;
    }
    
    modifier preventReentracy{
        if(mutex == false) {
            mutex = true;
            _;
            mutex = false;
        }
    }
    
    event BountyCreated(address sponsor_, string desc, uint devPctNumerator, uint devPctDenominator, uint value);
    event ValidatorAdded(address admin, address validator);
    event ValidatorRemoved(address admin, address validator);
    event BountyPaid(address validator, address payee, uint amount);
    event ValidatorPaid(address validator, uint amount);
    event Cleanup(address recipient, uint amount);
    
    //not sure positiveValue will work here
    //what sets contract balance?
    function BugBounty(address sponsor_, string desc, uint8 devPctNumerator_, uint8 devPctDenominator_) positiveValue payable {
        if(devPctNumerator_ >= devPctDenominator_) throw;
        //owner is creator
        provider = msg.sender;
        devPctNumerator = devPctNumerator_;
        devPctDenominator = devPctDenominator_;
        sponsor = sponsor_;
        description = desc;
        //bounty is the value attached to the contract
        
        //assume sponsor is one of the validators
        validators[sponsor] = 1;
        ValidatorAdded(provider,sponsor);
        BountyCreated(sponsor, description, devPctNumerator, devPctDenominator, this.balance);
        mutex = false;
        developerWasPaid = false;
        validatorWasPaid = false;
        
        developerBounty = devPctNumerator * this.balance / devPctDenominator;
        validatorBounty = (this.balance - developerBounty) / 2;
    }
    
    /*
    pays out some address, by convention the developer can include their 
    address when they commit their code.
    */
    function payOut(address payee) onlyValidator preventReentracy sufficientGas {
       
        //send to developer
        if(!developerWasPaid){
            developerWasPaid = payee.send(developerBounty);
            if(developerWasPaid){
                BountyPaid(msg.sender, payee, developerBounty);
            }
        }
        //send to validator
        if(!validatorWasPaid){
            validatorWasPaid = msg.sender.send(validatorBounty);
            if(validatorWasPaid) {
                ValidatorPaid(msg.sender, validatorBounty);
            }
        }
        
    }
    
    function addValidator(address validator) onlySponsor{
        validators[validator] = 1;
        ValidatorAdded(sponsor, validator);
    }
    
    function removeValidator(address validator) onlySponsor {
        validators[validator] = 0;
        ValidatorRemoved(sponsor, validator);
    }
    
    function getDescription() constant returns (string desc){
        return description;
    }
    
    function getBounty() constant returns (uint value){
        return this.balance * devPctNumerator / devPctDenominator;
    }
    
    //is it best practice to self-destruct when finished?
    function takedown() onlyProvider{
        Cleanup(provider, this.balance);
        selfdestruct(provider);
    }
    
    function getMinGasAmount() constant returns (uint gas){
        return minGas;
    }

}
