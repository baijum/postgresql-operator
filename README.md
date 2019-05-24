# PostgreSQL Operator: Deploy PostgreSQL on Kubernetes


To build:

	operator-sdk build quay.io/<username>/postgresql-operator:11

To push image:

	docker login quay.io -u <username>
	docker push quay.io/<username>/postgresql-operator:11
