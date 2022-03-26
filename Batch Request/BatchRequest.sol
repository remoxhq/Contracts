// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "./SafeMath.sol";
import "./ByteLib.sol";
import "./ExternalCall.sol";

contract RemoxBatchRequest {
    using SafeMath for uint256;
    using BytesLib for bytes;

    event TransactionExecution(
        address indexed destination,
        uint256 value,
        bytes data,
        bytes returnData
    );

    constructor() public {

    }

    function getAddress(bytes memory data) internal pure returns (address) {
        return toAddress(sliceData(data, 16, 20), 0);
    }

    function toAddress(bytes memory _bytes, uint256 _start)
        internal
        pure
        returns (address)
    {
        require(_start + 20 >= _start, "toAddress_overflow");
        require(_bytes.length >= _start + 20, "toAddress_outOfBounds");
        address tempAddress;

        assembly {
            tempAddress := div(
                mload(add(add(_bytes, 0x20), _start)),
                0x1000000000000000000000000
            )
        }

        return tempAddress;
    }

    function executeTransaction(
        address destination,
        uint256 value,
        bytes memory data
    ) public returns (bytes memory) {
        require(msg.sender == getAddress(data), "Invalid transaction sender");
        bytes memory returnData = ExternalCall.execute(
            destination,
            value,
            data
        );
        emit TransactionExecution(destination, value, data, returnData);
        return returnData;
    }

    function executeTransactions(
        address[] calldata destinations,
        uint256[] calldata values,
        bytes calldata data,
        uint256[] calldata dataLengths
    ) external returns (bytes memory, uint256[] memory) {
        require(
            destinations.length == values.length &&
                values.length == dataLengths.length,
            "Input arrays must be same length"
        );

        bytes memory returnValues;
        uint256[] memory returnLengths = new uint256[](destinations.length);
        uint256 dataPosition = 0;
        for (uint256 i = 0; i < destinations.length; i = i.add(1)) {
            bytes memory returnVal = executeTransaction(
                destinations[i],
                values[i],
                sliceData(data, dataPosition, dataLengths[i])
            );
            returnValues = abi.encodePacked(returnValues, returnVal);
            returnLengths[i] = returnVal.length;
            dataPosition = dataPosition.add(dataLengths[i]);
        }

        require(
            dataPosition == data.length,
            "data cannot have extra bytes appended"
        );
        return (returnValues, returnLengths);
    }

    function sliceData(
        bytes memory data,
        uint256 start,
        uint256 length
    ) internal pure returns (bytes memory) {
        // When length == 0 bytes.slice does not seem to always return an empty byte array.
        bytes memory sliced;
        if (length > 0) {
            sliced = data.slice(start, length);
        }
        return sliced;
    }
}

