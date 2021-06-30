## GitHub Packages for Docker Images

Reference. https://docs.github.com/en/packages/guides/pushing-and-pulling-docker-images 

Packages for Cloud Native GBB. https://github.com/orgs/CloudNativeGBB/packages

### How to

* Go to settings for org
    * Choose "Packages"
        * Settings
        * Check "Enable improved container support"
        * Check "Public" under "Container Creation"	

* GitHub Personal Access Token - Account settings		
    * Choose "Developer Settings"
		* Choose "Personal access tokens"
		* Click "Generate new token"
		* Give it a meaningful name (e.g., "Package Management")
		* Choose write:packages and delete:packages

* Now you can docker build and push (remember that docker enforces lowercase here and you will get a warning with mixed casing)

    ```bash
    # GitHub PAT (envvar or file)
    export CR_PAT=YOUR_TOKEN

    echo $CR_PAT | docker login ghcr.io -u chzbrgr71 --password-stdin
    cat ~/TOKEN.txt | docker login ghcr.io -u chzbrgr71 --password-stdin
    cat ~/TOKEN.txt  | helm registry login ghcr.io --username chzbrgr71 --password-stdin

    # old way
    docker tag chzbrgr71/flights-api:v2.0 docker.pkg.github.com/cloudnativegbb/paas-vnext/flights-api:v2.0

    # example (repo needs to be public)
    docker tag chzbrgr71/flights-api:v2.0 ghcr.io/cloudnativegbb/paas-vnext/flights-api:v2.0
    docker push ghcr.io/cloudnativegbb/paas-vnext/flights-api:v2.0
    ```

* Go to the org root at github (e.g., github.com/yourorg)
    * Click on the "Packages" tab
    * Click on your image (notice it currently has the "private" tag)
    * Click the "Package Settings" button
    * Under "Danger Zone" click "Change visibility"
    * Choose "Public" and finish filling out the acknowledgement (once you make it public, you can't make it private again)

* Make sure it all works by testing it out with a docker pull

    ```bash
    docker logout
    docker pull ghcr.io/cloudnativegbb/paas-vnext/flights-api:v2.0
    ```