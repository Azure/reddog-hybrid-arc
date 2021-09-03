## Release Schedule

### Milestone v1.0

Target: 9/27/2021 (GBB Airlift)

To do list:
* Create updated data file for products including category (Linda)
* Update microservices code where needed for above data file
* Finalize Infra automation (Key Vault secrets and other stuff from the doc)
* Update the manifests on the source repo (primarily the Helm fixes)
* SQL Server
  * Either Arc or SQL container
  * Need to automate DB creation and add connect string to KV
* Lima setup
* Arc Enabled API Management setup
* Automate creation of Web App UI and Function Apps in Lima (Corp Transfer Service)
* Create function for mobile orders created at Corp (Corp -> Store)
* Connect Mobile Apps to Corp order service (via APIM)
* UI Updates
* Contributor's Guide / Documentation
* Slide Deck, Videos, etc. - covering the business side and some of the technical decisions we have made


### Milestone vNext

Features:
* Complete Documentation
* Container Apps
* Event Grid
* Azure ML
