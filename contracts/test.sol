//SPDX-License-Identifier: MIT
pragma solidity 0.8.0;
contract Student{
    struct stu{
        string name;
        uint age;
        bool tookTest;
    }
    mapping(uint => stu) public studentNames;
    function addStudent(uint ID, string memory _name, uint _age)  public {
        studentNames[ID] = stu(_name, _age, false);
    }
    function updateStudent (uint ID) public{
        studentNames[ID].tookTest = true;
    }
}
contract ClassRoom {
    address studentAddr;
    Student student;
    constructor(address addr) {
        studentAddr = addr;
        student = Student(addr);
    }

    //some function that performs a check on student obj and updates the tookTest status to true
    function updateTookTest (uint ID) public {
        student.updateStudent(ID);
    }
    //if you want to access the public mapping
    function readStudentStruct (uint ID) public view returns (string memory) {
        return student.studentNames(ID).name;
    }
}