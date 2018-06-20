pragma solidity 0.4.24;

import "../../libs/ERC20Extended.sol";

interface OlympusExchangeAdapterManagerInterface {
    function pickExchange(ERC20Extended token, uint amount, uint rate, bool isBuying) external view returns (bytes32 exchangeId);
    function supportsTradingPair(address _srcAddress, address _destAddress, bytes32 _exchangeId) external view returns(bool supported);
    function getExchangeAdapter(bytes32 exchangeId) external view returns(address);
    function isValidAdapter(address adapter) external view returns(bool);
    function getPrice(ERC20Extended _sourceAddress, ERC20Extended _destAddress, uint _amount, bytes32 _exchangeId) external view
    returns(uint expectedRate, uint slippageRate);
}
