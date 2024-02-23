// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Test} from "forge-std/Test.sol";
import "forge-std/console2.sol";
import {IChromaticLP} from "~/lp/interfaces/IChromaticLP.sol";
import {CLBToken} from "@chromatic-protocol/contracts/core/CLBToken.sol";
import {IChromaticMarket} from "@chromatic-protocol/contracts/core/interfaces/IChromaticMarket.sol";

// forge test --match-contract ArbitrumOneForkTest -vvvv
contract ArbitrumOneForkTest is Test {
    uint256 arbitrumOneFork;
    IChromaticLP lpCrescendo = IChromaticLP(payable(0xAD6FE0A0d746aEEEDEeAb19AdBaDBE58249cD0c7));
    IChromaticLP lpPlateau = IChromaticLP(payable(0xFa334bE13bA4cdc5C3D9A25344FFBb312d2423A2));
    IChromaticLP lpDecresendo = IChromaticLP(payable(0x9706DE4B4Bb1027ce059344Cd42Bb57E079f64c7));
    IChromaticMarket market = IChromaticMarket(0x23d0bF4316F5c768Be8983f71f5C05717E13E5d5);
    CLBToken clbToken = CLBToken(0xbc9be0e4F7Eb9012BFb590c63F42CD6320b9648d);

    function setUp() public {
        string memory alchemyRpcUrl = "https://arb-mainnet.g.alchemy.com/v2/";
        string memory alchemyKey = vm.envString("ALCHEMY_KEY");
        string memory rpcUrl = string.concat(alchemyRpcUrl, alchemyKey);
        // before 0x02b146f458080a8cb2728893f4bde278c54156e08ecc95c51deb38b01066721f / 182825922
        arbitrumOneFork = vm.createFork(rpcUrl, 182825921);
    }

    function mockTotalSupplyBatch(uint256[] memory ids, uint256[] memory supplies) internal {
        vm.mockCall(
            address(clbToken),
            abi.encodeWithSelector(clbToken.totalSupplyBatch.selector, ids),
            abi.encode(supplies)
        );
    }

    function mockBalanceOfBatch(
        address[] memory accounts,
        uint256[] memory ids,
        uint256[] memory balances
    ) internal {
        vm.mockCall(
            address(clbToken),
            abi.encodeWithSelector(clbToken.balanceOfBatch.selector, accounts, ids),
            abi.encode(balances)
        );
    }

    function mockBinValues(int16[] memory feeRates, uint256[] memory values) internal {
        vm.mockCall(
            address(market),
            abi.encodeWithSelector(market.getBinValues.selector, feeRates),
            abi.encode(values)
        );
    }

    function testFork() public {
        vm.selectFork(arbitrumOneFork);
        uint256[] memory tokenIds = lpCrescendo.clbTokenIds();
        uint256[] memory supplies = new uint256[](tokenIds.length);
        uint256[] memory balances = new uint256[](tokenIds.length);
        address[] memory accounts = new address[](tokenIds.length);
        int16[] memory feeRates = lpCrescendo.feeRates();
        uint256[] memory binValues = new uint256[](feeRates.length);

        for (uint i = 0; i < tokenIds.length; i++) {
            supplies[i] = 1234567 ether;
            balances[i] = 231 ether;
            accounts[i] = address(lpCrescendo);
        }
        for (uint i = 0; i < feeRates.length; i++) {
            binValues[i] = 777 ether;
        }

        mockTotalSupplyBatch(tokenIds, supplies);
        mockBalanceOfBatch(accounts, tokenIds, balances);
        mockBinValues(feeRates, binValues);

        uint256[] memory ts = clbToken.totalSupplyBatch(tokenIds);
        uint256[] memory bs = clbToken.balanceOfBatch(accounts, tokenIds);
        for (uint i = 0; i < ts.length; i++) {
            emit log_uint(ts[i]);
            emit log_uint(bs[i]);
        }

        uint256[] memory vv = market.getBinValues(feeRates);
        for (uint i = 0; i < vv.length; i++) {
            emit log_uint(vv[i]);
        }

        assertEq(lpCrescendo.holdingClbValue() > 0, true);
    }

    function testFork2() public {
        vm.selectFork(arbitrumOneFork);

        assertEq(lpCrescendo.holdingClbValue(), 0);
    }
}

// function storeTotalSupplyBatch(uint256[] memory ids, uint256[] memory supplies) internal {
//         uint256 _totalSuppliesSlot = 3;
//         for (uint i = 0; i < ids.length; i++) {
//             vm.store(
//                 address(clbToken),
//                 keccak256(abi.encode(ids[i], _totalSuppliesSlot)),
//                 bytes32(uint256(supplies[i]))
//             );
//         }
//     }

//     function storeBalanceOfBatch(
//         address[] memory accounts,
//         uint256[] memory ids,
//         uint256[] memory balances
//     ) internal {
//         uint256 _balancesSlot = 0;
//         for (uint i = 0; i < ids.length; i++) {
//             bytes32 innerSlot = keccak256(abi.encode(ids[i], _balancesSlot));
//             vm.store(
//                 address(clbToken),
//                 keccak256(abi.encode(accounts[i], innerSlot)),
//                 bytes32(uint256(balances[i]))
//             );
//         }
//     }
