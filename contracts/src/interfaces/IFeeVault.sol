// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

interface IFeeVault {
    enum Bucket {
        DIVIDEND,
        SUPPORT
    }

    function credit(Bucket bucket, uint256 tokenAmount) external;
    function convertSupport(uint256 tokenAmount, uint256 minWbnbOut, uint256 deadline)
        external
        returns (uint256 wbnbOut);
    function dividendBalance() external view returns (uint256);
    function supportBalance() external view returns (uint256);
}
