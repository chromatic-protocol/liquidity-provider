// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@chromatic-protocol/contracts/core/interfaces/IChromaticMarket.sol";
import "~/automation/mate2/AutomateLP.sol";

library util {
    IERC20 constant USDT = IERC20(address(0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9));
    IChromaticMarket constant MARKET =
        IChromaticMarket(address(0x23d0bF4316F5c768Be8983f71f5C05717E13E5d5));
    AutomateLP constant AUTOMATE_LP =
        AutomateLP(address(0xb3C0d606327f406ce51B8C210b730460f372BF05));

    uint256 constant AUTOMATION_FEE_RESERVED = 50000000;
    uint16 constant UTILIZATION_TARGET_BPS = 2500;

    address constant KEEPER_REGISTRY = address(0x2959Cac7c8fB17Af213f6aA9ea50C3779FcEbbEa);
    address constant USER1 = address(0x6D330800687ee1B85D4aF30bFF6BC41638f21524);
    address constant USER2 = address(0x34D758979E9c71E62Ec9AE526E4541f2889A720b);
    address constant USER3 = address(0x829BFA66bA8265E5aAbe6829029dFcfc1f4e8e56);

    function feeRates() public pure returns (int16[] memory _feeRates) {
        // prettier-ignore
        int16[72] memory _fr = [-5000,-4500,-4000,-3500,-3000,-2500,-2000,-1500,-1000,-900,-800,-700,-600,-500,-400,-300,-200,-100,-90,-80,-70,-60,-50,-40,-30,-20,-10,-9,-8,-7,-6,-5,-4,-3,-2,-1,1,2,3,4,5,6,7,8,9,10,20,30,40,50,60,70,80,90,100,200,300,400,500,600,700,800,900,1000,1500,2000,2500,3000,3500,4000,4500,5000];

        _feeRates = new int16[](_fr.length);
        for (uint256 i = 0; i < _fr.length; i++) {
            _feeRates[i] = _fr[i];
        }
    }

    function distributionRates() public pure returns (uint16[] memory _distributionRates) {
        // prettier-ignore
        uint16[72] memory _dr = [1217,1200,1183,1165,1148,1130,1111,1092,1073,1054,1034,1014,994,973,952,930,907,884,861,837,812,786,759,732,703,673,642,609,574,537,497,454,406,352,287,203,203,287,352,406,454,497,537,574,609,642,673,703,732,759,786,812,837,861,884,907,930,952,973,994,1014,1034,1054,1073,1092,1111,1130,1148,1165,1183,1200,1217];

        _distributionRates = new uint16[](_dr.length);
        for (uint256 i = 0; i < _dr.length; i++) {
            _distributionRates[i] = _dr[i];
        }
    }
}
