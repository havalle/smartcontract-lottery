from brownie import accounts, config, network, MockV3Aggregator, Contract

LOCAL_NETWORKS = ["development", "ganache-local"]
FORKED_NETWORKS = ["mainnet-fork-alchemyapi"]


def get_account(index=None, id=None):
    if index:
        return accounts[index]

    if id:
        return accounts.load(id)

    if (
        network.show_active() in LOCAL_NETWORKS
        or network.show_active() in FORKED_NETWORKS
    ):
        return accounts[0]

    return accounts.add(config["wallets"]["from_key"])


contract_to_mock = {"eth_usd_price_feed": MockV3Aggregator}


def get_contract(contract_name):
    """
    This function will grab the contract addresses from the brownie config
    if defined, otherwise, it will deploy a mock version of that contract and
    return it.

        Args:
            contract_name (string)

        Returns:
            brownie.network.contract.ProjectContract: The most recently deployed
            version of this contract.
    """
    contract_type = contract_to_mock[contract_name]
    active_network = network.show_active()

    if active_network in LOCAL_NETWORKS:
        if len(contract_type) <= 0:
            deploy_mocks()

        contract = contract_type[-1]

    else:
        contract_address = config["networks"][active_network][contract_name]
        contract = Contract.from_abi(
            contract_type._name, contract_address, contract_type.abi
        )

    return contract


DECIMALS = 8
INITIAL_VALUE = 200000000000


def deploy_mocks(decimals=DECIMALS, initial_value=INITIAL_VALUE):
    account = get_account()
    MockV3Aggregator.deploy(decimals, initial_value, {"from": account})
    print("Deployed!!")
