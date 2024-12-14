// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./RoleManagement.sol";
import "@chainlink/contracts/src/v0.8/tests/MockV3Aggregator.sol";

contract PolicyManagement {

    RoleManagement private roleManagement;
    MockV3Aggregator public priceFeed; // Chainlink Mock price feed

    struct Policy {
        uint256 policyID;          
        string insurancePlan;            
        string basePremiumRate;
        uint256 deductible;
        uint256 insuranceCoverage;
        uint256 thirdPartyLiability;
        string[] cover;         
    }

    struct UserPolicySelection {
        uint256 policyID;
        uint256 premiumPriceETH; 
    }

    mapping(uint256 => Policy) public policies;
    mapping(address => UserPolicySelection[]) internal userPolicies;

    uint256 public policyCount;               

    event PolicyCreated(
        uint256 policyID,
        address indexed admin,
        string insurancePlan,
        string basePremiumRate,
        uint256 deductible,
        uint256 insuranceCoverage,
        uint256 thirdPartyLiability,
        string[] cover
    );

    event PolicySelected(
        address indexed user, 
        uint256 policyID, 
        uint256 premiumPriceETH
    );

    // Modifier for admin access control
    modifier onlyAdmin() {
        require(roleManagement.isAdmin(msg.sender), "Access denied: You are not Admin");
        _;
    }

    // Modifier for user access control
    modifier onlyUser() {
        require(roleManagement.isUser(msg.sender), "Access denied: You are not a Policy Holder");
        _;
    }

    constructor(address _roleManagementAddress, int256 _initialPrice) {
        roleManagement = RoleManagement(_roleManagementAddress);
        priceFeed = new MockV3Aggregator(8, _initialPrice); // 8 decimal places for USD/ETH
    }

    /*
     * @dev Admin creates a new policy. 
     */
    function createPolicy(
        string memory _insurancePlan,
        string memory _basePremiumRate,
        uint256 _deductible,
        uint256 _insuranceCoverage,
        uint256 _thirdPartyLiability,
        string[] memory _cover
    ) external onlyAdmin {
        policyCount++;
        policies[policyCount] = Policy(
            policyCount, 
            _insurancePlan, 
            _basePremiumRate, 
            _deductible, 
            _insuranceCoverage, 
            _thirdPartyLiability, 
            _cover
        );

        emit PolicyCreated(
            policyCount, 
            msg.sender, 
            _insurancePlan, 
            _basePremiumRate, 
            _deductible, 
            _insuranceCoverage, 
            _thirdPartyLiability, 
            _cover
        );
    }

    /*
     * @dev View details of a specific policy.
     */
    function viewPolicy(uint256 _policyID) external view returns (
        uint256 policyID,
        string memory insurancePlan,
        string memory basePremiumRate,
        uint256 deductible,
        uint256 insuranceCoverage,
        uint256 thirdPartyLiability,
        string[] memory cover
    ) {
        require(_policyID > 0 && _policyID <= policyCount, "Policy does not exist");

        Policy storage policy = policies[_policyID];

        return (
            policy.policyID,
            policy.insurancePlan,
            policy.basePremiumRate,
            policy.deductible,
            policy.insuranceCoverage,
            policy.thirdPartyLiability,
            policy.cover
        );
    }

    /*
     * @dev View all policies that exist in the contract.
     */
    function viewAllPolicies() external view returns (Policy[] memory) {
        Policy[] memory allPolicies = new Policy[](policyCount);
        for (uint256 i = 1; i <= policyCount; i++) {
            allPolicies[i - 1] = policies[i];
        }
        return allPolicies;
    }

    /*
     * @dev Allows users to select a policy and store the policyID with the premium price in ETH.
     */
    function selectPolicy(uint256 _policyID, uint256 _premiumInUSD) external payable onlyUser {
        require(_policyID > 0 && _policyID <= policyCount, "Policy does not exist");

        // Convert USD premium to ETH using Chainlink price feed
        uint256 premiumInETH = getUSDToETH(_premiumInUSD);

        userPolicies[msg.sender].push(UserPolicySelection(_policyID, premiumInETH));

        emit PolicySelected(msg.sender, _policyID, premiumInETH);
    }

    /*
     * @dev Converts USD to ETH using the Chainlink price feed.
     */
    function getUSDToETH(uint256 amountInUSD) public view returns (uint256) {
        (, int256 price, , ,) = priceFeed.latestRoundData();
        require(price > 0, "Invalid price feed");
        uint256 ethPrice = uint256(price); // Scale Chainlink price from 8 decimals to 18 decimals
        uint256 amountInWei = (amountInUSD * 1e18) / ethPrice; // convert to 18 decimal ETH


        return amountInWei;
    }

    /*
     * @dev View all selected policies for a specific user along with the premium price in ETH.
     */
    function getUserSelectedPolicies(address _user) external view returns (
        uint256[] memory policyIDs,
        uint256[] memory premiumPricesETH,
        Policy[] memory policyDetails
    ) {
        uint256 totalPolicies = userPolicies[_user].length;
        require(totalPolicies > 0, "User has not selected any policies");

        uint256[] memory policyIDArray = new uint256[](totalPolicies);
        uint256[] memory premiumPriceArray = new uint256[](totalPolicies);
        Policy[] memory policyDetailsArray = new Policy[](totalPolicies);

        for (uint256 i = 0; i < totalPolicies; i++) {
            UserPolicySelection storage userSelection = userPolicies[_user][i];
            policyIDArray[i] = userSelection.policyID;
            premiumPriceArray[i] = userSelection.premiumPriceETH;
            policyDetailsArray[i] = policies[userSelection.policyID];
        }

        return (policyIDArray, premiumPriceArray, policyDetailsArray);
    }
}
