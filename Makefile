YQ:=$(shell which yq)
JQ:=$(shell which jq)
KUBECTL:=$(shell which kubectl)
DOCKER:=$(shell which docker)
HELM:=$(shell which helm)
MINIKUBE:=$(shell which minikube)
KIND:=$(shell which kind)
PARENT_CHART_VALUES_FILE:="deploy-charts/values.yaml"
DEPLOYMENT_CHART_VALUES_FILE:="deploy-charts/charts/deployment/values.yaml"

DEFAULT_CLUSTER_NAME:="kind"
CLUSTER_NAME:=$(shell ${YQ} e '.clusterName' ${PARENT_CHART_VALUES_FILE})
K8S_ENGINE:=$(shell ${YQ} e '.k8s.engine' ${PARENT_CHART_VALUES_FILE})
DEPLOYMENT_RELEASE_NAME:=$(shell ${YQ} e '.deployemntReleaseName' ${PARENT_CHART_VALUES_FILE})
ARGO_ROLLOUTS_RELEASE_NAME:=$(shell ${YQ} e '.argoRolloutsReleaseName' ${PARENT_CHART_VALUES_FILE})
DEPLOYMENT_NAME:=$(shell ${YQ} e '.deployment.app.name' ${PARENT_CHART_VALUES_FILE})-deployment
APP_NAME:=$(shell ${YQ} e '.deployment.app.name' ${PARENT_CHART_VALUES_FILE})
APP_TAG:=$(shell ${YQ} e '.deployment.app.tag' ${PARENT_CHART_VALUES_FILE})
DEPLOY_NAMESPACE:=$(shell ${YQ} e '.deployment.namespace' ${DEPLOYMENT_CHART_VALUES_FILE})
ARGO_ROLLOUTS_NAMESPACE:=$(shell ${YQ} e '.argoRolloutsNamespace' ${PARENT_CHART_VALUES_FILE})
IMAGE_NAME_TAG:=$(APP_NAME):$(APP_TAG)
FULLY_QUALIFIED_IMAGE_URL:=$(ARTIFACT_REGISTRY)$(IMAGE_NAME_TAG)

# params-guard-%:
# 	@if [ "${${*}}" = "" ]; then \
# 			echo "[$*] not set"; \
# 			exit 1; \
# 	fi

# check_compulsory_params: params-guard-LAB

engine:
    ifeq ($(K8S_ENGINE), minikube)
			@echo "minikube"
    else ifeq ($(K8S_ENGINE), kind)
			@echo "kind"
    endif
		
print_mk_var:
	@echo "YQ: [$(YQ)]"
	@echo "KUBECTL: [$(KUBECTL)]"
	@echo "DOCKER: [$(DOCKER)]"
	@echo "MINIKUBE: [$(MINIKUBE)]"
	@echo "K8S_ENGINE: [$(K8S_ENGINE)]"
	@echo "PARENT_CHART_VALUES_FILE: [$(PARENT_CHART_VALUES_FILE)]"
	@echo "DEPLOYMENT_RELEASE_NAME: [$(DEPLOYMENT_RELEASE_NAME)]"
	@echo "ARGO_ROLLOUTS_RELEASE_NAME: [$(ARGO_ROLLOUTS_RELEASE_NAME)]"
	@echo "APP_NAME: [$(APP_NAME)]"
	@echo "APP_TAG: [$(APP_TAG)]"
	@echo "DEPLOY_NAMESPACE: [$(DEPLOY_NAMESPACE)]"
	@echo "ARGO_ROLLOUTS_NAMESPACE: [$(ARGO_ROLLOUTS_NAMESPACE)]"
	@echo "IMAGE_NAME_TAG: [$(IMAGE_NAME_TAG)]"
	@echo "FULLY_QUALIFIED_IMAGE_URL: [$(FULLY_QUALIFIED_IMAGE_URL)]"

create_deploy_namespace:
	$(KUBECTL) create namespace $(DEPLOY_NAMESPACE)

delete_deploy_namespace:
	$(KUBECTL) delete namespace $(DEPLOY_NAMESPACE)

create_argo_rollouts_namespace:
	$(KUBECTL) create namespace $(ARGO_ROLLOUTS_NAMESPACE)

delete_argo_rollouts_namespace:
	$(KUBECTL) delete namespace $(ARGO_ROLLOUTS_NAMESPACE)

build:
	$(DOCKER) build \
	-t $(IMAGE_NAME_TAG) \
	--pull \
	--no-cache \
	-f ./src/Dockerfile \
	./src

tag: 
	$(DOCKER) tag \
	$(IMAGE_NAME_TAG) \
	$(FULLY_QUALIFIED_IMAGE_URL)

load_image: 
    ifeq ($(K8S_ENGINE), minikube)
				$(MINIKUBE) image load $(FULLY_QUALIFIED_IMAGE_URL)
    else ifeq ($(K8S_ENGINE), kind)
			$(KIND) load docker-image $(FULLY_QUALIFIED_IMAGE_URL) --name $(CLUSTER_NAME)
    endif

build_tag_push_image:
	$(MAKE) build tag load_image

deployment_manifest:
	$(HELM) template --debug \
	-f deploy-charts/values.yaml \
	--set 'deployment.enabled=true' \
	--set 'strategy.enabled=false' \
	deploy-charts	

deployment_install:
	$(HELM) upgrade --install \
	--debug \
	-n $(DEPLOY_NAMESPACE) \
	-f deploy-charts/values.yaml \
	--set 'deployment.enabled=true' \
	--set 'strategy.enabled=false' \
	$(DEPLOYMENT_RELEASE_NAME) ./deploy-charts

deployment_update:
	$(HELM) upgrade --install \
	--debug \
	-n $(DEPLOY_NAMESPACE) \
	-f deploy-charts/values.yaml \
	--set 'deployment.enabled=true' \
	--set 'deployment.deployment.replicas=0' \
	--set 'strategy.enabled=false' \
	$(DEPLOYMENT_RELEASE_NAME) ./deploy-charts

deployment_scale_down: 
	$(KUBECTL) scale \
	deployment $(DEPLOYMENT_NAME) \
	-n $(DEPLOY_NAMESPACE) \
	--replicas 0

deployment_uninstall:
	$(HELM) helm uninstall $(RELEASE_NAME) 

argo_rollouts_controller_install: 
	$(KUBECTL) apply \
	-n $(ARGO_ROLLOUTS_NAMESPACE) \
	-f https://github.com/argoproj/argo-rollouts/releases/latest/download/install.yaml

argo_rollouts_controller_uninstall: 
	$(KUBECTL) delete \
	-n $(ARGO_ROLLOUTS_NAMESPACE) \
	-f https://github.com/argoproj/argo-rollouts/releases/latest/download/install.yaml

rollout_manifest:
	$(HELM) template --debug \
	-f deploy-charts/values.yaml \
	--set 'strategy.enabled=true' \
	--set 'deployment.enabled=false' \
	deploy-charts	

rollout_install: 
	$(MAKE) deployment_scale_down
	$(HELM) upgrade --install \
	-n $(DEPLOY_NAMESPACE) \
	-f deploy-charts/values.yaml \
	--set 'strategy.enabled=true' \
	--set 'deployment.enabled=false' \
	$(ARGO_ROLLOUTS_RELEASE_NAME) ./deploy-charts

cluster_start:
    ifeq ($(K8S_ENGINE), minikube)
			$(MINIKUBE) start
    else ifeq ($(K8S_ENGINE), kind)
			$(KIND) create cluster
    endif

cluster_stop:
    ifeq ($(K8S_ENGINE), minikube)
			$(MINIKUBE) stop
    endif
	
cluster_delete:
    ifeq ($(K8S_ENGINE), minikube)
			$(MINIKUBE) delete
    else ifeq ($(K8S_ENGINE), kind)
			$(KIND) delete cluster --name $(CLUSTER_NAME)
			$(KIND) delete cluster --name $(DEFAULT_CLUSTER_NAME)
    endif

create_cluster:
	$(KIND) create \
	cluster --config=infra/cluster.yaml \
	--name $(CLUSTER_NAME)

set_context_cluster:
	$(KUBECTL) config set-context $(CLUSTER_NAME)

cluster_info:
	$(KUBECTL) cluster-info --context kind-$(CLUSTER_NAME)

ingress_controller_install:
	$(KUBECTL) apply -f infra/ingress_controller.yaml
	@sleep 30
	$(MAKE) wait_for_ingress_controller
  
wait_for_ingress_controller:
	$(KUBECTL) wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=90s

all:
	$(MAKE) cluster_start \
	create_cluster \
	set_context_cluster \
	cluster_info \
	ingress_controller_install \
	wait_for_ingress_controller \
	create_argo_rollouts_namespace \
	argo_rollouts_controller_install \
	build_tag_push_image \
	create_deploy_namespace \
	deployment_install 

clean_up: cluster_stop cluster_delete


