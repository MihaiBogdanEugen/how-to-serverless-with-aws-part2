CODE_VERSION?=java

## help: Prints this help message
help:
	@echo "Usage: \n"
	@sed -n 's/^##//p' ${MAKEFILE_LIST} | column -t -s ':' |  sed -e 's/^/ /'

## clean: Clean the files and directories generated during build
clean:
	rm -rdf app/packages/
ifeq ($(CODE_VERSION), java)
	@(echo "Using Java11")
	cd app/java11/movies/ && ./gradlew clean
else ifeq ($(CODE_VERSION), python)
	@(echo "Using Python3.8")
else
	@(echo "ERROR: Unknown code version")
endif

## package: Build and package the source code into an uber-zip
package: clean check-pip3
	mkdir -p app/packages/
ifeq ($(CODE_VERSION), java)	
	$(call package_java_fn,get-movie)
	$(call package_java_fn,update-movie-rating)
	$(call package_java_fn,upload-movie-infos)
else ifeq ($(CODE_VERSION), python)
	$(call package_python_fn,get-movie)
	$(call package_python_fn,update-movie-rating)
	$(call package_python_fn,upload-movie-infos)
else
	@(echo "ERROR: Unknown code version")
endif

## reset-terraform: Reset Terraform state
reset-terraform:
	rm -rfd infrastructure/terraform/.terraform/ && \
	rm -f infrastructure/terraform/terraform.tfstate && \
	rm -f infrastructure/terraform/terraform.tfstate.backup

## format: Rewrites Terraform config files to canonical format
format: check-terraform
	cd infrastructure/terraform && terraform fmt -recursive

## init: Initialize a Terraform working directory
init: check-terraform
	cd infrastructure/terraform && terraform init

## validate: Validates the Terraform files
validate: check-terraform
	cd infrastructure/terraform && terraform validate

## plan: Generate and show a Terraform execution plan
plan: check-terraform
	cd infrastructure/terraform && terraform plan -var 'code_version=$(CODE_VERSION)'

## apply: Build or change Terraform infrastructure
apply: check-tf-var-aws-region check-tf-var-aws-account-id check-terraform
	cd infrastructure/terraform && terraform apply -auto-approve -var 'code_version=$(CODE_VERSION)'

## destroy: Destroy Terraform-managed infrastructure
destroy: check-terraform
	cd infrastructure/terraform && terraform destroy -auto-approve

## output: Read an output from a Terraform state file
output: check-terraform
	cd infrastructure/terraform && terraform output

## check-pip3: Locate pip3 in the current user's path (checking if it is installed or not)
check-pip3:
ifeq (, $(shell which pip3))
	$(error "pip3 is NOT installed correctly")
endif

## check-terraform: Locate terraform in the current user's path (checking if it is installed or not)
check-terraform:
ifeq (, $(shell which terraform))
	$(error "terraform is NOT installed correctly. More information: https://www.terraform.io/downloads.html")
endif

## check-tf-var-aws-region: Ensure the TF_VAR_aws_region environment variable is defined
check-tf-var-aws-region:
ifndef TF_VAR_aws_region
	$(error "TF_VAR_aws_region is undefined")
endif

## check-tf-var-aws-account-id: Ensure the TF_VAR_aws_account_id environment variable is defined
check-tf-var-aws-account-id:
ifndef TF_VAR_aws_account_id
	$(error "TF_VAR_aws_account_id is undefined")
endif

define package_java_fn
	cd app/java11/movies/ && \
	./gradlew :$(1):build && \
	cp $(1)/build/distributions/$(1).zip ../../packages/$(1).zip
endef

define package_python_fn
	cd app/python3.8/movies/ && \
	pip3 install -r requirements.txt -t ./temp/ && \
	cp -r $(1) temp/ && \
	cd ./temp/ && \
	zip -r9 ./../../../packages/$(1).zip . && \
	cd ../ &&\
	rm -rdf temp/
endef

.PHONY: help clean package reset-terraform format init validate plan apply destroy output check-pip3 check-terraform check-tf-var-aws-region check-tf-var-aws-account-id