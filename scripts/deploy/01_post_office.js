const { ethers } = require("hardhat");

module.exports = async ({ getNamedAccounts, deployments, getChainId }) => {
    const { deploy } = deployments;
    const { deployer } = await getNamedAccounts();
    const chainId = (await getChainId()).toString();

    let impl = await deploy('PostOfficeImpl', {
        from: deployer,
        contract: 'PostOffice',
        args: [],
        log: true,
        skipIfAlreadyDeployed: true,
    });

    const PostOffice = await ethers.getContractFactory('PostOffice')
    const postOfficeImpl = PostOffice.attach(impl.address)

    const fragment = PostOffice.interface.getFunction('initialize()');
    const postOfficeProxyData = postOfficeImpl.interface.encodeFunctionData(fragment, []);

    let proxyAdminAddress = '';
    if (proxyAdminAddress == '') {
        proxyAdminAddress = (await deployments.get('ProxyAdmin')).address;
    }

    const ProxyAdmin = await hre.ethers.getContractFactory("ProxyAdmin");
    const proxyAdmin = ProxyAdmin.attach(proxyAdminAddress);

    let proxy = await deploy('PostOffice', {
        from: deployer,
        contract: 'MyTransparentUpgradeableProxy',
        args: [impl.address, proxyAdminAddress, postOfficeProxyData],
        log: true,
        skipIfAlreadyDeployed: true,
    });
    const proxyAddress = proxy.address;
    const MyTransparentUpgradeableProxy = await ethers.getContractFactory('MyTransparentUpgradeableProxy')
    proxy = MyTransparentUpgradeableProxy.attach(proxy.address);

    let implAddress = await proxy.implementation();

    //BUG Unknown error. Check the call chain and find that the old impl address will be called.
    // if (implAddress !== ethers.AddressZero && implAddress !== impl.address) {
    //     await proxyAdmin.upgradeAndCall(proxyAddress, impl.address, postOfficeProxyData);
    //     console.log("upgrade Post Office impl done");
    // }

};
module.exports.tags = ['PostOffice'];