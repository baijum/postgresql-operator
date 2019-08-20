
QUAY_USERNAME ?= 
QUAY_PASSWORD ?= 

ifdef OPERATOR_TESTING
APPR_NAMESPACE ?= $(QUAY_USERNAME)-testing
else
APPR_NAMESPACE ?= $(QUAY_USERNAME)
endif
APPR_REPOSITORY ?= db-operators
OPERATOR_IMAGE ?= quay.io/$(APPR_NAMESPACE)/$(OPERATOR_NAME)
OPERATOR_NAME ?= postgresql-operator
# stable
OPERATOR_STABLE_VERSION ?= 0.0.5
# nightly
OPERATOR_NIGHTLY_VERSION ?= 0.0.6

BUILD_TAG = build-tag.txt
OPERATOR_MANIFESTS = tmp/manifests

.PHONY: clean
clean:
	@-rm -rvf ./vendor
	@-rm -rvf ./tmp
	@-rm -vf ./$(BUILD_TAG)

.PHONY: refresh-tag
refresh-tag:
	@date +%s > $(BUILD_TAG)

.PHONY: get-tag
ifeq "$(shell test -s $(BUILD_TAG) && echo yes)" "yes"
get-tag:
else
get-tag: refresh-tag
endif
	$(eval export TAG = $(shell cat $(BUILD_TAG)))

.PHONY: ./vendor
./vendor: go.mod go.sum
	go mod vendor

.PHONY: build-operator-image-nightly
build-operator-image-nightly: ./vendor refresh-tag get-tag
	operator-sdk build --image-builder buildah $(OPERATOR_IMAGE):$(OPERATOR_NIGHTLY_VERSION)-$(TAG)

.PHONY: push-operator-image-nightly
push-operator-image-nightly: get-tag
	@echo $(QUAY_PASSWORD) | podman login quay.io -u $(QUAY_USERNAME) --password-stdin
	podman push $(OPERATOR_IMAGE):$(OPERATOR_NIGHTLY_VERSION)-$(TAG)

.PHONY: package-operator
package-operator: get-tag
	$(eval CREATION_TIMESTAMP := $(shell date '+%Y-%m-%d %H:%M:%S'))

.PHONY: build-operator-image-stable
build-operator-image-stable: ./vendor
	operator-sdk build $(OPERATOR_IMAGE):$(OPERATOR_STABLE_VERSION)

.PHONY: push-operator-image-stable
push-operator-image-stable: build-operator-image-stable
	@echo $(QUAY_PASSWORD) | docker login quay.io -u $(QUAY_USERNAME) --password-stdin
	docker push $(OPERATOR_IMAGE):$(OPERATOR_STABLE_VERSION)

.PHONY: deploy-operator-package
deploy-operator-package: get-tag
	$(eval OPERATOR_MANIFESTS := tmp/manifests)
	$(eval CREATION_TIMESTAMP := $(shell date --date="@$(TAG)" '+%Y-%m-%d %H:%M:%S'))
	$(eval ICON_BASE64_DATA := $(shell cat ./icon/pgo.png | base64))
	mkdir -p $(OPERATOR_MANIFESTS)
	cp -vf manifests/stable/* $(OPERATOR_MANIFESTS)
	cp -vf manifests/database.package.yaml $(OPERATOR_MANIFESTS)
	cp -vf deploy/crds/*_crd.yaml $(OPERATOR_MANIFESTS)
	
	cp -vf manifests/nightly/* $(OPERATOR_MANIFESTS)
	@sed -i -e 's,REPLACE_NAME,$(OPERATOR_NAME),g' $(OPERATOR_MANIFESTS)/postgresql-operator.v$(OPERATOR_NIGHTLY_VERSION).clusterserviceversion.yaml
	@sed -i -e 's,REPLACE_VERSION,$(OPERATOR_NIGHTLY_VERSION),g' $(OPERATOR_MANIFESTS)/postgresql-operator.v$(OPERATOR_NIGHTLY_VERSION).clusterserviceversion.yaml
	@sed -i -e 's,REPLACE_TAG,$(TAG),g' $(OPERATOR_MANIFESTS)/postgresql-operator.v$(OPERATOR_NIGHTLY_VERSION).clusterserviceversion.yaml
	@sed -i -e 's,REPLACE_IMAGE,$(OPERATOR_IMAGE):$(OPERATOR_NIGHTLY_VERSION)-$(TAG),g' $(OPERATOR_MANIFESTS)/postgresql-operator.v$(OPERATOR_NIGHTLY_VERSION).clusterserviceversion.yaml
	@sed -i -e 's,REPLACE_CREATED_AT,$(CREATION_TIMESTAMP),' $(OPERATOR_MANIFESTS)/postgresql-operator.v$(OPERATOR_NIGHTLY_VERSION).clusterserviceversion.yaml
	@sed -i -e 's,REPLACE_ICON_BASE64_DATA,$(ICON_BASE64_DATA),' $(OPERATOR_MANIFESTS)/postgresql-operator.v$(OPERATOR_NIGHTLY_VERSION).clusterserviceversion.yaml

	@sed -i -e 's,REPLACE_NAME,$(OPERATOR_NAME),g' $(OPERATOR_MANIFESTS)/database.package.yaml
	@sed -i -e 's,REPLACE_STABLE_VERSION,$(OPERATOR_STABLE_VERSION),g' $(OPERATOR_MANIFESTS)/database.package.yaml
	@sed -i -e 's,REPLACE_NIGHTLY_VERSION,$(OPERATOR_NIGHTLY_VERSION),g' $(OPERATOR_MANIFESTS)/database.package.yaml
	@sed -i -e 's,REPLACE_TAG,$(TAG),g' $(OPERATOR_MANIFESTS)/database.package.yaml
	@sed -i -e 's,REPLACE_PACKAGE,$(APPR_REPOSITORY),' $(OPERATOR_MANIFESTS)/database.package.yaml
	operator-courier --verbose verify --ui_validate_io $(OPERATOR_MANIFESTS)


.PHONY: push-operator-package
push-operator-package: get-tag
	@$(eval QUAY_API_TOKEN := $(shell curl -sH "Content-Type: application/json" -XPOST https://quay.io/cnr/api/v1/users/login -d '{"user":{"username":"'${QUAY_USERNAME}'","password":"'${QUAY_PASSWORD}'"}}' | jq -r '.token'))
	@operator-courier push $(OPERATOR_MANIFESTS) $(APPR_NAMESPACE) $(APPR_REPOSITORY) $(OPERATOR_NIGHTLY_VERSION)-$(TAG) "$(QUAY_API_TOKEN)"

.PHONY: install-operator-source
install-operator-source:
	$(eval INSTALL_DIR := deploy/install)
	sed -e 's,REPLACE_NAMESPACE,$(APPR_NAMESPACE),g' ./$(INSTALL_DIR)/operatorsource.yaml | sed -e 's,REPLACE_REPOSITORY,$(APPR_REPOSITORY),g' | oc apply -f -

.PHONY: uninstall-operator
uninstall-operator:
	#$(eval INSTALL_DIR := deploy/install)
	@-oc delete sub $(APPR_REPOSITORY) -n openshift-operators
	@-oc delete catsrc installed-custom-openshift-operators -n openshift-operators
	@-oc delete csc installed-custom-openshift-operators -n openshift-marketplace
	@-oc delete opsrc $(APPR_REPOSITORY) -n openshift-marketplace
	@-oc delete crd databases.postgresql.baiju.dev
	@-oc delete deploy $(OPERATOR_NAME) -n openshift-operators
	@-oc delete csv $(OPERATOR_NAME).v$(OPERATOR_VERSION) -n openshift-operators
	

.PHONY: reinstall-operator
reinstall-operator: uninstall-operator deploy-operator-package install-operator-source

.PHONY: nightly-all
nightly-all:	build-operator-image-nightly push-operator-image-nightly package-operator