//SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;
contract Contract {
    uint[] public values;

    function Contract() {
    }

    function find(uint value) returns(uint) {
        uint i = 0;
        while (values[i] != value) {
            i++;
        }
        return i;
    }

   
    function test() returns(uint[]) {
        values.push(10);
        values.push(20);
        values.push(30);
        values.push(40);
        values.push(50);
        removeByValue(30);
        return getValues();
    }
}