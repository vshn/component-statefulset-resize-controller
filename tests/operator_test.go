package tests

import (
	"io/ioutil"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"sigs.k8s.io/yaml"

	appv1 "k8s.io/api/apps/v1"
	corev1 "k8s.io/api/core/v1"
	rbacv1 "k8s.io/api/rbac/v1"
)

var (
	operator      = "statefulset-resize-controller-manager"
	operatorImage = "quay.io/vshn/statefulset-resize-controller:v0.2.0"
	rsyncImage    = "quay.io/instrumentisto/rsync-ssh:alpine3.14"

	roleName        = "statefulset-resize-controller-manager"
	rolebindingName = "statefulset-resize-manager-rolebinding"
	saName          = "statefulset-resize-controller-manager"
)

func Test_OperatorDeployment(t *testing.T) {
	deploy := &appv1.Deployment{}
	data, err := ioutil.ReadFile(testPath + "/10_deployment.yaml")
	require.NoError(t, err)
	err = yaml.UnmarshalStrict(data, deploy)
	require.NoError(t, err)

	assert.Equal(t, operator, deploy.Name)
	assert.Equal(t, namespace, deploy.Namespace)

	require.NotEmpty(t, deploy.Spec.Template.Spec.Containers)
	require.Len(t, deploy.Spec.Template.Spec.Containers, 1)
	c := deploy.Spec.Template.Spec.Containers[0]

	assert.Equal(t, operatorImage, c.Image)

	require.Len(t, c.Args, 2)
	assert.Equal(t, rsyncImage, c.Args[1])

	assert.Equal(t, saName, deploy.Spec.Template.Spec.ServiceAccountName)
}

func Test_OperatorRBAC(t *testing.T) {
	role := &rbacv1.Role{}
	data, err := ioutil.ReadFile(testPath + "/10_clusterrole.yaml")
	require.NoError(t, err)
	err = yaml.UnmarshalStrict(data, role)
	require.NoError(t, err)

	assert.Equal(t, roleName, role.Name)
	assert.Equal(t, namespace, role.Namespace)

	rolebinding := &rbacv1.RoleBinding{}
	data, err = ioutil.ReadFile(testPath + "/10_clusterrolebinding.yaml")
	require.NoError(t, err)
	err = yaml.UnmarshalStrict(data, rolebinding)
	require.NoError(t, err)

	assert.Equal(t, rolebindingName, rolebinding.Name)
	assert.Equal(t, namespace, rolebinding.Namespace)
	require.NotEmpty(t, rolebinding.Subjects)
	require.Len(t, rolebinding.Subjects, 1, "RoleBinding is referencing unknown Subjects")
	assert.Equal(t, namespace, rolebinding.Subjects[0].Namespace)
	assert.Equal(t, saName, rolebinding.Subjects[0].Name)
	assert.Equal(t, role.Name, rolebinding.RoleRef.Name, "RoleBinding is not referencing the Role")

	sa := &corev1.ServiceAccount{}
	data, err = ioutil.ReadFile(testPath + "/10_serviceaccount.yaml")
	require.NoError(t, err)
	err = yaml.UnmarshalStrict(data, sa)
	require.NoError(t, err)

	assert.Equal(t, saName, sa.Name)
	assert.Equal(t, namespace, sa.Namespace)
}
