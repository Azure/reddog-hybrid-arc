## Red Dog Demo - Hybrid Arc Deployment (Retail)

### Background

This is the hybrid cloud deployment of the [Red Dog Demo](https://github.com/Azure/reddog-code). This is an example deployment showcasing the following technologies:

* Azure Arc
* Arc Enabled Application Services
* Arc Enabled Data Services
* Dapr
* AKS
* Azure PaaS platform

The business scenario is a Retail operation with applications that run in a branch office as well as Corporate. These branch stores can run in Azure or in a hybrid scenario with local compute with a connection to the cloud. If there is a loss of network connectivity, they still need to be able to process orders locally in each store. 

### Architecture

Architecture Diagram

![Architecture diagram](assets/architecture.png)

### Getting Started

This repo contains the scripts and configurations to deploy the [Red Dog Demo](https://github.com/Azure/reddog-code) to an example Hybrid Cloud environment. You will use a GitHub Codespaces environment to run the automated deployment script. 

Get started in your own Azure sub in the [Quickstart.](docs/quickstart.md)

### Contributing

This project welcomes contributions and suggestions.  Most contributions require you to agree to a
Contributor License Agreement (CLA) declaring that you have the right to, and actually do, grant us
the rights to use your contribution. For details, visit https://cla.opensource.microsoft.com.

When you submit a pull request, a CLA bot will automatically determine whether you need to provide
a CLA and decorate the PR appropriately (e.g., status check, comment). Simply follow the instructions
provided by the bot. You will only need to do this once across all repos using our CLA.

This project has adopted the [Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct/).
For more information see the [Code of Conduct FAQ](https://opensource.microsoft.com/codeofconduct/faq/) or
contact [opencode@microsoft.com](mailto:opencode@microsoft.com) with any additional questions or comments.
