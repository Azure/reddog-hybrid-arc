## Red Dog Demo - Deploy via make

The following is a prototype of a deployment using a Makefile for orchestration. There have also been serveral modifications intended to improve readability of the scripts. 

Run 'make help' to see the full list of commands that can be used.

```bash 
make help
Usage:
   make all             - create a cluster and deploy the apps
   make hubinfra        - run the hub bicep deployment
   make configurehub    - run the steps to configure the hub resources
   make createbranches  - create all of the branches in config.json
   make cleanall        - cleanup branches, hub, logs and ssh keys
   make cleanhub        - cleanup hub, logs and ssh keys
   make cleanbranches   - cleanup branches
```

Expected flow would be either to run 'make all', or to run:

1. make hubinfra
1. make configurehub
1. make createbranches
