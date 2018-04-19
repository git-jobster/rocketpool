const $Web3 = require('web3');
const $web3 = new $Web3('http://localhost:8545');

import { getABI, getContractAddressFromStorage } from './utils';

export const RocketUser = artifacts.require('./contract/RocketUser');
export const RocketNode = artifacts.require('./contract/RocketNode');
export const RocketPool = artifacts.require('./contract/RocketPool');
export const RocketPoolMini = artifacts.require('./contract/RocketPoolMini');
export const RocketDepositToken = artifacts.require('./contract/RocketDepositToken');
export const RocketPartnerAPI = artifacts.require('./contract/RocketPartnerAPI');
export const RocketVault = artifacts.require('./contract/RocketVault');
export const RocketVaultStore = artifacts.require('./contract/RocketVaultStore');
export const RocketRole = artifacts.require('./contract/RocketRole');
export const RocketSettings = artifacts.require('./contract/RocketSettings');
export const RocketStorage = artifacts.require('./contract/RocketStorage');
export const RocketUpgrade = artifacts.require('./contract/RocketUpgrade');
export const CasperDummy = artifacts.require('./contract/Casper/DummyCasper');
export const CasperValidation = artifacts.require('./contract/Casper/Validation');

