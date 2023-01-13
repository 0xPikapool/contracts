import { Wallet } from 'ethers';
import fs from 'fs';

// this script securely generates the specified number of user accounts as signers
// appropriate entropy is provided using keccak256 on 16 randomBytes with optional extraEntropy

// nvm it just stores accounts with PKs

type Account = {
    address: string;
    privKey: string;
}

const generateUser = (): Account => {
    const wallet = Wallet.createRandom();
    const user: Account = {
        address: wallet.address,
        privKey: wallet.privateKey
    }

    return user;
    }

const main = async (amount: number) => {
    const accounts: Account[] = [];
    console.log('Generating accounts...');

    for (let i = 0; i < amount; ++i) {
        accounts.push(generateUser());
    }
    console.log(JSON.stringify(accounts))

    fs.appendFile('.env.users.json', JSON.stringify(accounts), err => {
        if (err) {
            console.error(err);
        }
    })

}

// run script with provided amount and passwd parameters in command line
main(Number(process.argv[2]));