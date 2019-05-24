# PostgreSQL Operator: Deploy PostgreSQL on Kubernetes


To build:

	operator-sdk build quay.io/<username>/postgresql-operator:11

To push image:

	docker login quay.io -u <username>
	docker push quay.io/<username>/postgresql-operator:11

To run the operator locally:

	kubectl apply -f deploy/crds/postgresql_v1alpha1_database_crd.yaml
	kubectl apply -f deploy/crds/postgresql_v1alpha1_database_cr.yaml
	operator-sdk up local
