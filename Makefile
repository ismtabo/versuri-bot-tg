DOCKER_USER             ?= ismtabo
DOCKER_PASSWORD         ?=
DOCKER_REGISTRY         ?= hub.docker.com/
DOCKER_ORG              ?= 
DOCKER_PROJECT          ?= go-server-template
DOCKER_API_VERSION      ?=
DOCKER_IMAGE            ?= $(if $(DOCKER_REGISTRY),$(DOCKER_REGISTRY)/$(DOCKER_ORG)/$(DOCKER_PROJECT),$(DOCKER_ORG)/$(DOCKER_PROJECT))
DOCKER_SERVICES         ?= server mongo

USER_UID                ?= $(shell id -u)
USER_GID                ?= $(shell id -g)
HOST_UID_GID            ?=

PRODUCT_VERSION         ?=
PRODUCT_REVISION        ?=
BUILD_VERSION           ?= $(PRODUCT_VERSION)-$(PRODUCT_REVISION)
LDFLAGS_OPTIMIZATION    ?= -w -s
LDFLAGS                 ?= $(LDFLAGS_OPTIMIZATION)

DOCKER_COMPOSE_PROJECT  := $(shell echo '$(DOCKER_PROJECT)' | sed -e 's/[^a-z0-9]//g')
DOCKER_COMPOSE_ENV      := HOST_UID_GID='$(USER_UID):$(USER_GID)'
DOCKER_COMPOSE          := $(DOCKER_COMPOSE_ENV) docker-compose -p '$(DOCKER_COMPOSE_PROJECT)'

# Get the environment and import the settings.
# If the make target is pipeline-xxx, the environment is obtained from the target.
ifeq ($(patsubst pipeline-%,%,$(MAKECMDGOALS)),$(MAKECMDGOALS))
	ENVIRONMENT ?= pull
else
	override ENVIRONMENT := $(patsubst pipeline-%,%,$(MAKECMDGOALS))
endif

# Shell settings
SHELL := bash
.ONESHELL:

define help
Usage: make <command>
Commands:
  help:              Show this help information
  clean:             Clean the project (remove build directory, clean golang packages and tidy go.mod file)
  swagger:           Generate the swagger specification from annotations in source code
  build-config:      Copy the configuration and swagger specification into build/bin directory
  build-bin:         Build the application into build/bin directory
  build-test-deps:   Install the golang dependencies for linter and coverage
  build-test:        Pass linter, unit tests and coverage reports (in build/cover)
  build-chown:       Change owner of the build directory to host user (develenv container creates the directory in the shared volume with root)
  build:             Build the application. Orchestrates: build-bin, build-config, build-test and build-chown
  test-acceptance:   Pass acceptance tests locally
  login:             Docker login to publish and promote docker images
  package:           Create the docker image
  publish:           Publish the docker image in the docker repository
  promote:           Tag the docker image when it is promoted
  deploy:            Deploy the application with ansible.
  run:               Launch the application
  pipeline-pull:     Launch pipeline to handle a pull request
  pipeline-dev:      Launch pipeline to handle the merge of a pull request
  pipeline:          Launch the pipeline for the selected environment
  ci-pipeline:       Start up a development environment to launch a pipeline. When the pipeline is completed, the development environment is shut down
  develenv-up:       Launch the development environment with a docker-compose of the service
  develenv-sh:       Access to a shell of the develenv service.
  develenv-down:     Stop the development environment
endef
export help

check-%:
	@if [ -z '${${*}}' ]; then echo 'Environment variable $* not set' && exit 1; fi

.PHONY: help
help:
	@echo "$$help"

.PHONY: clean
clean:
	$(info) 'Cleaning the project'
	rm -rf build/
	go clean
	go mod tidy

.PHONY: swagger
swagger:
	$(info) 'Generate swagger specification'
	swagger generate spec -o ./swagger.yml

.PHONY: build-config
build-config:
	$(info) 'Copying configuration and JSON schemas'
	mkdir -p build/bin
	cp config.yml build/bin/

.PHONY: build-bin
build-bin:
	$(info) 'Building version: $(BUILD_VERSION)'
	mkdir -p build/bin
	go build -v -ldflags='$(LDFLAGS)' -o build/bin ./...

.PHONY: build-test-deps
build-test-deps:
	$(info) 'Installing golang dependencies for lint and coverage'
	go get -v \
		golang.org/x/lint/golint \
		github.com/t-yuki/gocover-cobertura

.PHONY: build-test
build-test: build-test-deps
	# Linter
	$(info) 'Passing linter'
	golint -set_exit_status $(get_packages)
	# Unit tests and coverage
	$(info) 'Passing unit tests and coverage'
	mkdir -p build/cover
	go test -coverprofile=build/cover/cover.out $(get_packages)
	# Coverage reports (at build/cover) in html and xml format
	go tool cover -func=build/cover/cover.out
	go tool cover -html=build/cover/cover.out -o build/cover/cover.html
	gocover-cobertura < build/cover/cover.out > build/cover/cover.xml

.PHONY: build-chown
build-chown:
	@if [ '$(HOST_UID_GID)' != '' ]; then
		$(info) 'Chown build directory to $(HOST_UID_GID)'
		chown -R $(HOST_UID_GID) build
	fi

.PHONY: build
build: build-bin build-config build-test build-chown

.PHONY: test-acceptance
test-acceptance:
	$(info) 'Passing test acceptance'
	test/acceptance/test-acceptance.sh

.PHONY: package
package:
	$(info) 'Creating the docker image $(DOCKER_IMAGE):$(BUILD_VERSION)'
	docker build \
		--build-arg PRODUCT_VERSION='$(PRODUCT_VERSION)' \
		--build-arg PRODUCT_REVISION='$(PRODUCT_REVISION)' \
		-t '$(DOCKER_IMAGE):$(BUILD_VERSION)' .

.PHONY: login
login: check-DOCKER_PASSWORD
	$(info) 'Docker login with user $(DOCKER_USER) in $(DOCKER_REGISTRY)'
	echo $(DOCKER_PASSWORD) | docker login --username '$(DOCKER_USER)' --password-stdin '$(DOCKER_REGISTRY)'

.PHONY: publish
publish: login
	@for version in $(BUILD_VERSION) $(PRODUCT_VERSION) latest; do
		$(info) "Publishing the docker image: $(DOCKER_IMAGE):$$version"
		docker tag '$(DOCKER_IMAGE):$(BUILD_VERSION)' "$(DOCKER_IMAGE):$$version"
		docker push "$(DOCKER_IMAGE):$$version"
	done

.PHONY: deploy
deploy:
	$(info) 'Deploying the service $(DOCKER_PROJECT):$(BUILD_VERSION) in environment $(ENVIRONMENT)'

.PHONY: run
run:
	$(info) 'Launching the service'
	build/bin/ingestion_agent

.PHONY: pipeline-pull
pipeline-pull: build test-acceptance
	$(info) 'Completed successfully pipeline-pull'

.PHONY: pipeline-dev
pipeline-dev: build test-acceptance
	$(info) 'Completed successfully pipeline-dev'

.PHONY: pipeline
pipeline: pipeline-$(ENVIRONMENT)

.PHONY: ci-pipeline
ci-pipeline: check-PRODUCT_VERSION check-PRODUCT_REVISION
	$(info) 'Launching the CI pipeline for environment: $(ENVIRONMENT) and version: $(BUILD_VERSION)'
	function shutdown {
		rm -rf build/
		docker cp $$($(DOCKER_COMPOSE) -f docker-compose.yml ps -q develenv):/src/build . || true
		@for service in $(DOCKER_SERVICES); do \
			servicename="$(DOCKER_COMPOSE_PROJECT)"_"$$service"_"1"
			docker logs $$servicename > build/acceptance/logs/$$servicename.log
		done
		$(DOCKER_COMPOSE) -f docker-compose.yml down --remove-orphans
	}
	trap 'shutdown' EXIT

	# Export variables for creating the docker image for admin service with docker-compose
	export DOCKER_IMAGE='$(DOCKER_IMAGE):$(BUILD_VERSION)' \
		PRODUCT_VERSION='$(PRODUCT_VERSION)' \
		PRODUCT_REVISION='$(PRODUCT_REVISION)' \
		HOST_UID_GID='$(HOST_UID_GID)'

	# Start up the development environment disabling the default port mapping in the host
	# and using the target "build" because mounting a volume could fail if the docker engine
	# is remote. This is done by excluding docker-compose.override.yml
	$(DOCKER_COMPOSE) -f docker-compose.yml up --build -d

	# In CI, disable TTY in docker-compose with option -T
	$(DOCKER_COMPOSE) -f docker-compose.yml exec -T develenv make pipeline-$(ENVIRONMENT)

.PHONY: develenv-up
develenv-up:
	$(info) 'Launching the development environment: $(PRODUCT_VERSION)-$(PRODUCT_REVISION)'
	$(DOCKER_COMPOSE) up --build -d

.PHONY: develenv-sh
develenv-sh:
	$(DOCKER_COMPOSE) exec develenv bash

.PHONY: develenv-down
develenv-down:
	$(info) 'Shutting down the development environment'
	$(DOCKER_COMPOSE) down --remove-orphans

# Functions
info := @printf '\033[32;01m%s\033[0m\n'
get_packages := $$(go list ./... | grep -v test/acceptance)
