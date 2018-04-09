'use strict'
//
/*
测试
1. 测试提交Token
2. 测试提交交易所
3. 测试提交TokenProvider
4. 测试更新价格 循环
5. 测试获取价格
*/

// contract PriceProviderInterface {
    
//     function updatePrice(address _tokenAddress,bytes32[] _exchanges,uint[] _prices,uint _nonce) public returns(bool success);

//     function getNewDefaultPrice(address _tokenAddress) public view returns(uint);

//     function getNewCustomPrice(address _provider,address _tokenAddress) public view returns(uint);

//     function GetNonce(address providerAddress,address tokenAddress) public view returns(uint);
  
//     function checkTokenSupported(address tokenAddress)  public view returns(bool success);

//     function checkExchangeSupported(bytes32 Exchanges)  public view returns(bool success);

//     function checkProviderSupported(address providerAddress,address tokenAddress)  public view returns(bool success);
 
// }

const PriceProvider = artifacts.require("../contracts/price/PriceProvider.sol");
const Web3 = require('web3');
const web3 = new Web3();
const _ = require('lodash');
const Promise = require('bluebird');
const mockData = { 
    id: 0,
    name: "Price",
    description: "Test PriceProvider",
    category: "multiple",
    tokenAddresses: ["0xEa1887835D177Ba8052e5461a269f42F9d77A5Af","0x569b92514E4Ea12413dF6e02e1639976940cDe70"],
    exchangesAddressHash: ["0x6269626f78","0x1269626f78"],
    //providerAddresses: [accounts[2],accounts[3]],
    tokenOnePrice: [1000000,20000],
    tokenTwoPrice: [3000000,40000]
}
contract('PriceProvider', (accounts) => {
  
    it("They should be able to deploy.", () => {
        return Promise.all([
        PriceProvider.deployed(),
        //Strategy.deployed(),
        // Exchange.deployed(),
    ]).spread((/*price, strategy, exchange,*/ core) =>  {
        assert.ok(core, 'PriceProvider contract is not deployed.');
        });
    });

    it("Should be able to update support price.", async () => {
        let instance  = await PriceProvider.deployed();
        let result = await instance.changeTokens(mockData.tokenAddresses,{from:accounts[0]});
        assert.equal(result.receipt.status, '0x01');
    })
    it("Should be able to check support price.", async () => {
        let instance  = await PriceProvider.deployed();
        let result1 = await instance.checkTokenSupported(mockData.tokenAddresses[0],{from:accounts[0]});
        let result2 = await instance.checkTokenSupported(mockData.tokenAddresses[1],{from:accounts[0]});
        let result3 = await instance.checkTokenSupported(accounts[0],{from:accounts[0]});
        assert.equal(result1, true);
        assert.equal(result2, true);
        assert.equal(result3, false);
    })


    it("Should be able to update support exchanges.", async () => {
        let instance  = await PriceProvider.deployed();
        let result = await instance.changeExchanges(mockData.exchangesAddressHash,{from:accounts[0]});
        assert.equal(result.receipt.status, '0x01');
    })

    it("Should be able to check support exchanges.", async () => {
        let instance  = await PriceProvider.deployed();
        let result1 = await instance.checkExchangeSupported(mockData.exchangesAddressHash[0],{from:accounts[0]});
        let result2 = await instance.checkExchangeSupported(mockData.exchangesAddressHash[1],{from:accounts[0]});
        let result3 = await instance.checkExchangeSupported(accounts[0],{from:accounts[0]});
        assert.equal(result1, true);
        assert.equal(result2, true);
        assert.equal(result3, false);
    })

    it("Should be able to update support Provider.", async () => {
        let instance  = await PriceProvider.deployed();
        let result1 = await instance.changeProviders([accounts[1],accounts[2]],mockData.tokenAddresses[0],{from:accounts[0]});
        let result2 = await instance.changeProviders([accounts[2],accounts[1]],mockData.tokenAddresses[1],{from:accounts[0]});
        assert.equal(result1.receipt.status, '0x01');
        assert.equal(result2.receipt.status, '0x01');
    })

    it("Should be able to check support provider.", async () => {
        let instance  = await PriceProvider.deployed();
        let result1 = await instance.checkProviderSupported(accounts[1],mockData.tokenAddresses[0],{from:accounts[0]});
        let result2 = await instance.checkProviderSupported(accounts[2],mockData.tokenAddresses[0],{from:accounts[0]});
        let result3 = await instance.checkProviderSupported(accounts[3],mockData.tokenAddresses[0],{from:accounts[0]});
        let result4 = await instance.checkProviderSupported(accounts[1],mockData.tokenAddresses[1],{from:accounts[0]});
        let result5 = await instance.checkProviderSupported(accounts[2],mockData.tokenAddresses[1],{from:accounts[0]});
        let result6 = await instance.checkProviderSupported(accounts[3],mockData.tokenAddresses[1],{from:accounts[0]});
        assert.equal(result1, true);
        assert.equal(result2, true);
        assert.equal(result3, false);
        assert.equal(result4, true);
        assert.equal(result5, true);
        assert.equal(result6, false);
    })
    it("Should be able to update price.", async () => {
        let instance  = await PriceProvider.deployed();
        let nonce1 = 0;
        let nonce2 = 0;
        let result1 = await instance.updatePrice(mockData.tokenAddresses[0],mockData.exchangesAddressHash,mockData.tokenOnePrice,nonce1,{from:accounts[1]});
        nonce1 =+ 1;
        let result2 = await instance.updatePrice(mockData.tokenAddresses[0],mockData.exchangesAddressHash,mockData.tokenTwoPrice,nonce2,{from:accounts[2]});
        nonce2 =+ 1;
        let result3 = await instance.updatePrice(mockData.tokenAddresses[0],mockData.exchangesAddressHash,mockData.tokenTwoPrice,nonce1,{from:accounts[1]});
        
        let result4 = await instance.updatePrice(mockData.tokenAddresses[0],mockData.exchangesAddressHash,mockData.tokenOnePrice,nonce2,{from:accounts[2]});
        assert.equal(result1.receipt.status, '0x01');
        assert.equal(result2.receipt.status, '0x01');
        assert.equal(result3.receipt.status, '0x01');
        assert.equal(result4.receipt.status, '0x01');
    });

    it("Should be able to check price.", async () => {
        let instance  = await PriceProvider.deployed();

        let result1 = await instance.getNewDefaultPrice(mockData.tokenAddresses[0],{from:accounts[0]});
        assert.equal(result1.c[0],mockData.tokenTwoPrice[0]);
        let result2 = await instance.getNewCustomPrice(accounts[2],mockData.tokenAddresses[0],{from:accounts[0]});
        assert.equal(result2.c[0],mockData.tokenOnePrice[0]);
    });

});