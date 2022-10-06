SHELL := /bin/bash
.PHONY: help all hubinfra createbranches cleanall cleanhub cleanbranches

help :
	@echo "Usage:"
	@echo "   make all		- create a cluster and deploy the apps"
	@echo "   make hubinfra	- run the hub bicep deployment"
	@echo "   make configurehub	- run the steps to configure the hub resources"
	@echo "   make createbranches	- create all of the branches in config.json"
	@echo "   make cleanall	- cleanup branches, hub, logs and ssh keys"
	@echo "   make cleanhub	- cleanup hub, logs and ssh keys"
	@echo "   make cleanbranches	- cleanup branches"

all : hubinfra configurehub createbranches

hubinfra :
	mkdir -p logs
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
