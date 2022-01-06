SHELL := /bin/bash
.PHONY: help all hubinfra createbranches cleanall cleanhub cleanbranches

help :
	@echo "Usage:"
	@echo "   make all		- create a cluster and deploy the apps"
	@echo "   make hubinfra	- run the hub bicep deployment"
	@echo "   make createbranches	- create all of the branches in config.json"
	@echo "   make cleanup		- run the hub bicep deployment"

all : hubinfra configurehub createbranches

hubinfra :
	mkdir logs
	./scripts/create-hub-infra.sh 2>&1 | tee -a ./logs/hub-deployment.log

configurehub : 
	./scripts/configure-hub.sh 2>&1 | tee -a ./logs/hub-deployment.log

createbranches :
	./scripts/create-branch-infra.sh

cleanall : cleanhub cleanbranches

cleanhub :
	./scripts/cleanup-hub.sh

cleanbranches :
	./scripts/cleanup-branches.sh