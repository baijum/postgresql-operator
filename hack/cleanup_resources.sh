kubectl delete -f deploy/operator.yaml
kubectl delete -f deploy/role_binding.yaml
kubectl delete -f deploy/role.yaml
kubectl delete -f deploy/service_account.yaml
kubectl delete -f deploy/crds/postgresql_v1alpha1_database_cr.yaml
kubectl delete -f deploy/crds/postgresql_v1alpha1_database_crd.yaml
