import 'dotenv/config';
import Web3 from 'web3';
import ERC20ABI from './erc20-abi.js';

const web3 = new Web3(process.env.BASE_RPC);
const contract = new web3.eth.Contract(ERC20ABI, process.env.NPT_CONTRACT);

(async () => {
  try {
    const balance = await contract.methods.balanceOf(process.env.WALLET).call();
    const formatted = parseFloat(web3.utils.fromWei(balance)).toFixed(4);
    process.stdout.write(formatted);
  } catch (err) {
    process.stdout.write("0.0000");
  }
})();
