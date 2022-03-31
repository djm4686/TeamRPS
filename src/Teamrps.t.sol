// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.6;

import "ds-test/test.sol";

import "./Teamrps.sol";

contract TeamrpsTest is DSTest {
    Teamrps teamrps;

    function setUp() public {
        teamrps = new Teamrps();
    }

    function testFail_basic_sanity() public {
        assertTrue(false);
    }

    function test_basic_sanity() public {
        assertTrue(true);
    }
}
