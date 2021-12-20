# Setting up to run tests

* `npm ci`

* Set variables in `.env` file

* `npm run test`

---
## Deploy on Rinkeby:

* Uncomment and set variables in `.env` file ([Rinkeby] section)

### then

`npx hardhat deploy --network rinkeby`

## or

`npx hardhat run scripts/deploy.ts --network rinkeby`
