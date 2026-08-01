// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Pangu2IntegrationTest} from "../Pangu2Integration.t.sol";
import {Pangu2Token} from "pangu2/Pangu2Token.sol";
import {Pangu2TradeRouter} from "pangu2/Pangu2TradeRouter.sol";
import {TransferContext} from "pangu2/libraries/TransferContext.sol";

contract ForgedSystemCaller {
    function forge(Pangu2Token token, address recipient, uint256 amount) external {
        token.systemTransfer(recipient, amount, TransferContext.Kind.SYSTEM_CREDIT_UNKNOWN);
    }
    function forgeSettlement(Pangu2Token token, address recipient, uint256 amount) external {
        token.settleBuy(recipient, amount, 1 ether);
    }
}

contract ReentrantSeller {
    Pangu2TradeRouter public immutable router;
    IERC20 public immutable token;
    bool public reentrySucceeded;
    constructor(address router_, address token_) {
        router = Pangu2TradeRouter(payable(router_));
        token = IERC20(token_);
    }
    receive() external payable {
        token.approve(address(router), 100);
        (reentrySucceeded,) = address(router).call(abi.encodeCall(Pangu2TradeRouter.sell, (100, 1, block.timestamp + 5 minutes)));
    }
    function execute(uint256 amount) external {
        token.approve(address(router), amount);
        router.sell(amount, 1, block.timestamp + 5 minutes);
    }
}

contract TransferContextAttacksTest is Pangu2IntegrationTest {
    function testUnregisteredContractCannotForgeSystemTransferContext() public {
        ForgedSystemCaller attacker = new ForgedSystemCaller();
        token.transfer(address(attacker), 1 ether);
        vm.expectRevert(Pangu2Token.TransferContextNotAllowed.selector);
        attacker.forge(token, USER, 1 ether);
    }
    function testUnregisteredRouterCannotInvokeSettlementPrimitive() public {
        ForgedSystemCaller attacker = new ForgedSystemCaller();
        vm.expectRevert();
        attacker.forgeSettlement(token, USER, 1 ether);
    }
    function testEmergencyCannotEscalateItsOwnRole() public {
        vm.prank(EMERGENCY);
        vm.expectRevert();
        token.grantRole(token.GOVERNANCE_ROLE(), EMERGENCY);
    }
    function testRouterNativeCallbackCannotReenterSell() public {
        ReentrantSeller seller = new ReentrantSeller(address(tradeRouter), address(token));
        token.transfer(address(seller), 1 ether);
        seller.execute(0.5 ether);
        assertFalse(seller.reentrySucceeded());
    }
}
