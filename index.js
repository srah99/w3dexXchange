const connectButton = document.getElementById("connectButton");
connectButton.onclick = connect;

async function connect(){
    if (typeof window.ethereum !== "undefined"){
        try{
        await window.ethereum.request({method:"eth_requestAccounts"});
        }catch(error){console.log(error);}
        connectButton.innerHTML="Connected";
        const accounts = await window.ethereum.request({method:"eth_accounts"});
    }
}