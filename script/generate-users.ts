import { Wallet } from 'ethers';
import fs from 'fs';

// this script securely generates the specified number of user accounts as signers
// appropriate entropy is provided using keccak256 on 16 randomBytes with optional extraEntropy

const main = async () => {
    const encryptions = JSON.stringify(await generateUsers(Number(process.argv[2]), String(process.argv[3])));
    console.log((encryptions) + '\nWriting to file ../.env.users.json ...');
    fs.appendFile('.env.users.json', encryptions, err => {
        if (err) {
            console.error(err)
        }
    })
}

const generateUsers = async (amount: number, pass: string): Promise<String[]> => {
    const accounts: String[] = []
    const prog: number = amount / 100;

    for (let i = 0; i < amount; ++i) {
        accounts.push(JSON.parse(await Wallet.createRandom().encrypt(pass)));
        let status: number = i % prog;
        if (i > prog && Math.floor(status) == 0) {
            let percent: number = i / prog;
            console.log(`Generating and encrypting accounts: ${percent}% complete.`);
        }
    }

    return accounts
}

// run script with provided amount and passwd parameters in command line
main()