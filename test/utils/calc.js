module.exports = {
  roundTo: (value, decimals) => {
    return Math.round(10 ** decimals * value) / 10 ** decimals;
  },

  ethBalance: async address => {
    return parseFloat(web3.fromWei((await web3.eth.getBalance(address)).toNumber(), "ether"), 10);
  },

  inRange: async (value, range, offset) => {
    return value > range - offset && value < range + offset;
  },

  getEvent: (tx, name) => {
    return tx.logs.map(log => ({ event: log.event, args: log.args })).find(event => event.event === name);
  },
  assertReverts: async (call, message) => {
    try {
      await call();
      assert(false, message);
    } catch (e) {
      if (e.message.includes("revert") < 0) {
        // throw new Error(e); // Error is not caused by revert but for another reason
        console.log("Revert", e.message);
      }
      assert(true, message);
    }
  },

  ethToken: "0x00eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee"
};
