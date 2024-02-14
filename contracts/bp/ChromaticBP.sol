// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import {AutomateReady} from "@chromatic-protocol/contracts/core/automation/gelato/AutomateReady.sol";
import {Module, ModuleData} from "@chromatic-protocol/contracts/core/automation/gelato/Types.sol";
import {IKeeperFeePayer} from "@chromatic-protocol/contracts/core/interfaces/IKeeperFeePayer.sol";

import {IChromaticLP} from "~/lp/interfaces/IChromaticLP.sol";
import {IChromaticLPCallback} from "~/lp/interfaces/IChromaticLPCallback.sol";
import {ChromaticLPReceipt} from "~/lp/libraries/ChromaticLPReceipt.sol";
import {TrimAddress} from "~/lp/libraries/TrimAddress.sol";

import {IChromaticBP, IChromaticBPAction, IChromaticBPLens, IChromaticBPAutomate, IChromaticBPAdmin} from "~/bp/interfaces/IChromaticBP.sol";
import {IChromaticBPFactory} from "~/bp/interfaces/IChromaticBPFactory.sol";
import {IAutomateBP} from "~/bp/interfaces/IAutomateBP.sol";

import {BPConfig} from "~/bp/libraries/BPConfig.sol";
import {BPState, BPPeriod, BPExec, BPStatus} from "~/bp/libraries/BPState.sol";
import {BPStateLib} from "~/bp/libraries/BPState.sol";

/**
 * @title ChromaticBP
 * @dev ChromaticBP is a contract representing a BP (boosting pool) for boosting liquidity of LP in the Chromatic Protocol.
 */
contract ChromaticBP is ERC20, ReentrancyGuard, IChromaticBP, IChromaticLPCallback {
    using BPStateLib for BPState;
    using Math for uint256;

    BPState s_state;
    uint256 constant MIN_PERIOD = 1 days;
    IChromaticBPFactory immutable _factory;

    /**
     * @dev Modifier to restrict the execution of a function to only the designated automation account.
     */
    modifier onlyAutomation() virtual {
        if (msg.sender != address(s_state.automateBP())) revert NotAutomationCalled();
        _;
    }

    modifier verifyCallback() virtual {
        if (address(s_state.targetLP()) != msg.sender) revert NotLPCalled();
        _;
    }

    modifier onlyDao() {
        if (msg.sender != _factory.marketFactory().dao()) revert OnlyAccessableByDao();
        _;
    }

    /**
     * @dev Constructs the ChromaticBP contract.
     * @param config The configuration parameters for the ChromaticBP.
     * @param _bpFactory The ChromaticBPFactory.
     */
    constructor(BPConfig memory config, IChromaticBPFactory _bpFactory) ERC20("", "") {
        _checkArgs(config);

        emit SetTotalReward(config.totalReward);

        s_state.init(config);
        if (address(_bpFactory) == address(0)) revert ZeroBPFactory();
        _factory = _bpFactory;
    }

    /**
     * @dev Checks the validity of the configuration parameters.
     * @param config The configuration parameters for the ChromaticBP.
     */
    function _checkArgs(BPConfig memory config) internal view {
        //slither-disable-next-line timestamp
        if (config.startTimeOfWarmup <= block.timestamp) {
            revert StartTimeError();
        }
        if (config.maxDurationOfWarmup < MIN_PERIOD) {
            revert InvalidWarmup();
        }
        if (config.durationOfLockup < MIN_PERIOD) {
            revert InvalidLockup();
        }
        if (config.minRaisingTarget < config.lp.estimateMinAddLiquidityAmount()) {
            revert TooSmallMinRaisingTarget();
        }
        if (config.minRaisingTarget > config.maxRaisingTarget) {
            revert InvalidRaisingTarget();
        }
        if (config.minDeposit < config.lp.estimateMinAddLiquidityAmount()) {
            revert TooSmallMinDeposit();
        }
    }

    /**
     * @dev Creates a boost LP task to automate the boosting process.
     */
    function _createBoostTask() internal {
        // check needToCreateBoostTask(s_state)
        IAutomateBP automate = _factory.automateBP();
        s_state.setAutomateBP(automate);
        automate.createBoostTask();
    }

    /**
     * @inheritdoc IChromaticBPAction
     */
    function deposit(uint256 amount) external override nonReentrant {
        if (s_state.isBPCanceled()) revert FundingCanceled();
        if (amount == 0) revert ZeroDepositError();

        if (currentPeriod() == BPPeriod.WARMUP) {
            uint256 maxDepositable = s_state.maxDepositable();
            uint256 _minDeposit = s_state.config.minDeposit;
            if (maxDepositable > _minDeposit && amount < _minDeposit) revert TooSmallDepositError();

            uint256 depositAmount = maxDepositable >= amount ? amount : maxDepositable;
            if (depositAmount > 0) {
                emit BPDeposited(msg.sender, depositAmount);
                SafeERC20.safeTransferFrom(
                    settlementToken(),
                    msg.sender,
                    address(this),
                    depositAmount
                );
                _mint(msg.sender, depositAmount);
                s_state.addRaised(depositAmount);

                if (depositAmount == maxDepositable) {
                    emit BPFullyRaised(s_state.totalRaised());
                    s_state.setStartTimeOfLockup(block.timestamp);
                }

                if (s_state.needToCreateBoostTask()) {
                    emit BPBoostTaskCreated();
                    _createBoostTask();
                }
            } else {
                revert FullyRaised();
            }
        } else {
            revert NotWarmupPeriod();
        }
    }

    /**
     * @inheritdoc IChromaticBPAction
     */
    function refund() external override nonReentrant {
        //slither-disable-next-line timestamp
        if (!s_state.isBPCanceled()) {
            if (block.timestamp < s_state.startTimeOfWarmup()) revert NotRefundablePeriod();
            if (s_state.isRaisedOverMinTarget()) revert RefundError();
        }
        _refund();
    }

    function _refund() internal {
        uint256 amount = balanceOf(msg.sender);
        if (amount > 0) {
            emit BPRefunded(msg.sender, amount);
            _burn(msg.sender, amount);
            SafeERC20.safeTransfer(settlementToken(), msg.sender, amount);
        } else {
            revert RefundZeroAmountError();
        }
    }

    /**
     * @inheritdoc IChromaticBPAction
     */
    function claimLiquidity() external override nonReentrant {
        if (s_state.boostingExecStatus() == BPExec.NOT_EXECUTED) revert BoostingNotExecuted();
        if (s_state.boostingExecStatus() == BPExec.EXECUTED) revert BoostingNotSettled();

        //slither-disable-next-line timestamp
        if (block.timestamp <= s_state.endTimeOfLockup()) revert ClaimTimeError();

        uint256 amount = balanceOf(msg.sender); // BLP amount to burn
        if (amount == 0) revert ClaimBalanceZeroError();

        uint256 lpAmount = s_state.totalLPToken().mulDiv(amount, s_state.totalRaised());

        emit BPClaimed(msg.sender, amount, lpAmount);
        _burn(msg.sender, amount);
        SafeERC20.safeTransfer(IERC20(s_state.targetLP().lpToken()), msg.sender, lpAmount);
    }

    /**
     * @inheritdoc IChromaticBPLens
     */
    function totalRaised() external view override returns (uint256 amount) {
        return s_state.totalRaised();
    }

    /**
     * @inheritdoc IChromaticBPLens
     */
    function minRaisingTarget() external view override returns (uint256 amount) {
        return s_state.minRaisingTarget();
    }

    /**
     * @inheritdoc IChromaticBPLens
     */
    function maxRaisingTarget() external view override returns (uint256 amount) {
        return s_state.maxRaisingTarget();
    }

    /**
     * @inheritdoc IChromaticBPLens
     */
    function minDeposit() external view returns (uint256 amount) {
        return s_state.config.minDeposit;
    }

    /**
     * @inheritdoc IChromaticBPLens
     */
    function startTimeOfWarmup() external view override returns (uint256 timestamp) {
        return s_state.startTimeOfWarmup();
    }

    /**
     * @inheritdoc IChromaticBPLens
     */
    function endTimeOfWarmup() external view override returns (uint256 timestamp) {
        return s_state.endTimeOfWarmup();
    }

    /**
     * @inheritdoc IChromaticBPLens
     */
    function endTimeOfLockup() external view override returns (uint256 timestamp) {
        return s_state.endTimeOfLockup();
    }

    /**
     * @inheritdoc IChromaticBPLens
     */
    function targetLP() external view override returns (IChromaticLP lpAddress) {
        return s_state.targetLP();
    }

    /**
     * @inheritdoc IChromaticBPLens
     */
    function settlementToken() public view override returns (IERC20 token) {
        return s_state.settlementToken();
    }

    /**
     * @inheritdoc IChromaticBPLens
     */
    function currentPeriod() public view override returns (BPPeriod period) {
        return s_state.currentPeriod();
    }

    /**
     * @inheritdoc ERC20
     */
    function name() public view virtual override(IERC20Metadata, ERC20) returns (string memory) {
        return
            string(
                abi.encodePacked(
                    "ChromaticBP - ",
                    TrimAddress.trimAddress(address(s_state.targetLP()), 4)
                )
            );
    }

    /**
     * @inheritdoc ERC20
     */
    function symbol() public view virtual override(IERC20Metadata, ERC20) returns (string memory) {
        return
            string(
                abi.encodePacked("BLP-", TrimAddress.trimAddress(address(s_state.targetLP()), 4))
            );
    }

    /**
     * @inheritdoc ERC20
     */
    function decimals() public view virtual override(IERC20Metadata, ERC20) returns (uint8) {
        return s_state.settlementToken().decimals();
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 /* amount */
    ) internal virtual override(ERC20) {
        if (from != address(0) && to != address(0)) {
            revert NonTransferable();
        }
    }

    /**
     * @inheritdoc IChromaticBPAutomate
     */
    function checkBoost() external view override returns (bool) {
        if (s_state.isBoostExecutable()) {
            return true;
        } else {
            return false;
        }
    }

    /**
     * @inheritdoc IChromaticBPAction
     */
    function boost() external override nonReentrant {
        if (s_state.isBoostExecutable()) {
            _boostLP();
            _cancelBoostTask();
        } else {
            revert NotBoostable();
        }
    }

    function _cancelBoostTask() internal {
        // cancel task if manually executed
        IAutomateBP automate = s_state.automateBP();
        if (address(automate) != address(0)) {
            try automate.cancelBoostTask(IChromaticBP(this)) {} catch {}
        }
    }

    function _boostLP() internal {
        IChromaticLP lp = s_state.targetLP();
        IERC20 token = s_state.settlementToken();
        uint256 balance = token.balanceOf(address(this));

        SafeERC20.forceApprove(token, address(lp), balance);
        ChromaticLPReceipt memory receipt = lp.addLiquidity(balance, address(this));
        emit BPBoostTaskExecuted();
        s_state.setBoostingReceiptId(receipt.id);
        s_state.setBoostingExecStatus(BPExec.EXECUTED);
    }

    function _payKeeperFee(
        uint256 maxFeeInSettlementToken,
        address feePayee,
        uint256 keeperFee
    ) internal virtual returns (uint256 feeInSettlementAmount) {
        IKeeperFeePayer payer = IKeeperFeePayer(s_state.market().factory().keeperFeePayer());

        IERC20 token = s_state.settlementToken();
        SafeERC20.safeTransfer(token, address(payer), maxFeeInSettlementToken);

        feeInSettlementAmount = payer.payKeeperFee(address(token), keeperFee, feePayee);
    }

    /**
     * @inheritdoc IChromaticBPAutomate
     */
    function boostTask(
        address feePayee,
        uint256 keeperFee
    ) external override nonReentrant onlyAutomation {
        if (s_state.isBoostExecutable()) {
            _payKeeperFee(s_state.targetLP().automationFeeReserved(), feePayee, keeperFee);
            _boostLP();
        }
    }

    /**
     * @inheritdoc IChromaticBPLens
     */
    function isDepositable() external view returns (bool) {
        return s_state.isDepositable();
    }

    /**
     * @inheritdoc IChromaticBPLens
     */
    function isRefundable() external view returns (bool) {
        return s_state.isRefundable();
    }

    /**
     * @inheritdoc IChromaticBPLens
     */
    function isClaimable() external view returns (bool) {
        return s_state.isClaimable();
    }

    /**
     * @inheritdoc IChromaticBPLens
     */
    function totalReward() external view returns (uint256) {
        return s_state.totalReward();
    }

    /**
     * @inheritdoc IChromaticBPLens
     */
    function status() external view returns (BPStatus) {
        return s_state.status();
    }

    /**
     * @inheritdoc IChromaticLPCallback
     */
    function claimedCallback(
        uint256 /* receiptId */,
        uint256 /* addedLiquidity */,
        uint256 lpTokenMint,
        uint256 /* keeperFee */
    ) external override verifyCallback {
        // when boost settled
        emit BPSettleUpdated(lpTokenMint);
        s_state.updateBoostingSettleState(lpTokenMint);
    }

    /**
     * @inheritdoc IChromaticLPCallback
     */
    function withdrawnCallback(
        uint256 receiptId,
        uint256 burnedAmount,
        uint256 withdrawnAmount,
        uint256 refundedAmount,
        uint256 keeperFee
    ) external override {
        // not used
    }

    /**
     * @inheritdoc IChromaticBPLens
     */
    function bpFactory() external view returns (address) {
        return address(_factory);
    }

    /**
     * @inheritdoc IChromaticBPLens
     */
    function automateBP() external view returns (address) {
        return address(s_state.info.automateBP);
    }

    /**
     * @inheritdoc IChromaticBPAdmin
     */
    function cancelBP() external onlyDao {
        if (s_state.boostingExecStatus() != BPExec.NOT_EXECUTED) revert BoostingAlreadyExecuted();
        emit BPCanceled();
        s_state.cancelBP();
        _cancelBoostTask(); // if task created but not executed then cancel task
    }
}
