const { ethers } = require("hardhat");

module.exports = async ({ getNamedAccounts, deployments, getChainId }) => {
    const { deploy } = deployments;
    const { deployer } = await getNamedAccounts();
    const chainId = (await getChainId()).toString();

    let implAddress;
    try {
        implAddress = (await deployments.get('RouterImpl')).address
    } catch (error) {
    }

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

    await deploy('PostOffice', {
        from: deployer,
        contract: 'MyTransparentUpgradeableProxy',
        args: [impl.address, proxyAdminAddress, postOfficeProxyData],
        log: true,
        skipIfAlreadyDeployed: true,
    });

    if (implAddress !== ethers.AddressZero && implAddress !== impl.address) {
        await proxyAdmin.upgrade(router.address, impl.address);
        console.log("upgrade Post Office impl done");
    }

};
module.exports.tags = ['PostOffice'];