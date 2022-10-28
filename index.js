import {ethers} from "./ethers-5.6.esm.min.js"
import {contractAddress} from "./constant.js"

const connectButton = document.getElementById("connectButton");
const balanceButton = document.getElementById("balanceButton");
const fundButton = document.getElementById("fundButton");
connectButton.onclick = connect;
balanceButton.onclick =getBalance;


async function connect(){
    if (typeof window.ethereum !== "undefined"){
        try{
        await window.ethereum.request({method:"eth_requestAccounts"});
        }catch(error){console.log(error);}
        connectButton.innerHTML="Connected";
        const accounts = await window.ethereum.request({method:"eth_accounts"});
    }
}
async function getBalance(){
    if(typeof window.ethereum !== "undefined"){
        const provider = new ethers.providers.Web3Provider(window.ethereum);
        const balance = await provider.getBalance("contractAddress");
        console.log(balance.toString());

        //provider = ethers.providers.RPCProvider("http://loaclhost:someport")
     //const balance = await provider.getbalance(address) ;

    }
}
async function fund(){
    const ethAmount = document.getElementById("ethAmount").value;
    console.log('Funding with{ethAmount}...');
    if (typeof ethAmount !== "undefined"){
        const provider = new ethers.providers.Web3Provider(window.etherum);
        const sighner = provider.getSigner();
        const contract = new ethers.Contract(contractAddress, (?? put here abi,is usaully in the json file), signer);
    }
}