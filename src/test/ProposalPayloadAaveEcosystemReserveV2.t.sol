// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import { IERC20 } from "../contracts/dependencies/openZeppelin/IERC20.sol";
import { ProposalPayloadAaveEcosystemReserveV2 } from "../contracts/ProposalPayloadAaveEcosystemReserveV2.sol";
import { AaveGovHelpers, IAaveGov } from "./utils/AaveGovHelpers.sol";
import { AaveEcosystemReserveV2 } from "../contracts/AaveEcosystemReserveV2.sol";
import { ProposalPayloadLongExecutor } from "../contracts/ProposalPayloadLongExecutor.sol";

contract ProposalPayloadAaveEcosystemReserveV2Test is Test {
    IERC20 constant AAVE_TOKEN =
        IERC20(0x7Fc66500c84A76Ad7e9c93437bFc5Ac33E2DDaE9);
    address internal constant AAVE_WHALE =
        address(0x25F2226B597E8F9514B3F68F00f494cF4f286491);
    
    uint256 public proposalId;
    uint256 public votingPower;

    address public oldFundsAdmin;
    uint256 public oldNextStreamId;

    AaveEcosystemReserveV2 ecosystemReserve;
    AaveEcosystemReserveV2 aaveEcosystemReserveImpl;
    ProposalPayloadAaveEcosystemReserveV2 proposalPayloadEcosystem;


    function setUp() public {
        aaveEcosystemReserveImpl = new AaveEcosystemReserveV2();

        proposalId = _createMockProposal();

        proposalPayloadEcosystem = new ProposalPayloadAaveEcosystemReserveV2(
            address(aaveEcosystemReserveImpl),
            proposalId
        );

        votingPower = AAVE_TOKEN.balanceOf(proposalPayloadEcosystem.ECOSYSTEM_PROXY_ADDRESS());
        ecosystemReserve = AaveEcosystemReserveV2(payable(proposalPayloadEcosystem.ECOSYSTEM_PROXY_ADDRESS()));

        oldFundsAdmin = ecosystemReserve.getFundsAdmin();
        oldNextStreamId = ecosystemReserve.getNextStreamId();
    }

    function testProposal() public {
        address[] memory targets = new address[](1);
        targets[0] = address(proposalPayloadEcosystem);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        string[] memory signatures = new string[](1);
        signatures[0] = "execute()";
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = "";
        bool[] memory withDelegatecalls = new bool[](1);
        withDelegatecalls[0] = true;

        uint256 ecosystemProposalId = AaveGovHelpers._createProposal(
            vm,
            AAVE_WHALE,
            IAaveGov.SPropCreateParams({
                executor: AaveGovHelpers.SHORT_EXECUTOR,
                targets: targets,
                values: values,
                signatures: signatures,
                calldatas: calldatas,
                withDelegatecalls: withDelegatecalls,
                ipfsHash: bytes32(0)
            })
        );

        AaveGovHelpers._passVote(vm, AAVE_WHALE, ecosystemProposalId);
        _validateEcosystemNewInterface();
        _validateEcosystemVoted(ecosystemProposalId);
    }

    function _validateEcosystemNewInterface() internal {
        assertEq(oldFundsAdmin, ecosystemReserve.getFundsAdmin());
        assertEq(oldNextStreamId, ecosystemReserve.getNextStreamId());
    }

    function _validateEcosystemVoted(uint256 id) internal {
        IAaveGov.ProposalWithoutVotes memory proposalData = AaveGovHelpers
            ._getProposalById(proposalId);
        
        assertEq(proposalData.forVotes, votingPower);
    }


    function _createMockProposal() internal returns (uint256) {
        address longExecutor = deployCode(
            "out/LongExecutor.sol/Executor.json",
            abi.encode(
                address(1234),
                604800,
                432000,
                604800,
                864000,
                200,
                64000,
                1500,
                1200
            )
        );
        ProposalPayloadLongExecutor proposalPayload = new ProposalPayloadLongExecutor(
                longExecutor
            );

        address[] memory targets = new address[](1);
        targets[0] = address(proposalPayload);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        string[] memory signatures = new string[](1);
        signatures[0] = "execute()";
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = "";
        bool[] memory withDelegatecalls = new bool[](1);
        withDelegatecalls[0] = true;

        uint256 id = AaveGovHelpers._createProposal(
            vm,
            AAVE_WHALE,
            IAaveGov.SPropCreateParams({
                executor: AaveGovHelpers.LONG_EXECUTOR,
                targets: targets,
                values: values,
                signatures: signatures,
                calldatas: calldatas,
                withDelegatecalls: withDelegatecalls,
                ipfsHash: bytes32(0)
            })
        );

        return id;
    }
}