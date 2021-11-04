// main template for statefulset-resize-controller
local kap = import 'lib/kapitan.libjsonnet';
local kube = import 'lib/kube.libjsonnet';
local inv = kap.inventory();
// The hiera parameters for the component
local params = inv.parameters.statefulset_resize_controller;

local prefix = 'statefulset-resize-';

local role = std.parseJson(kap.yaml_load('statefulset-resize-controller/manifests/operator/' + params.manifest_version + '/role.yaml'));
local service_account = std.parseJson(
  kap.yaml_load('statefulset-resize-controller/manifests/operator/' + params.manifest_version + '/service_account.yaml')
) {
  metadata+: {
    name: prefix + super.name,
  },
};
local role_binding = std.parseJson(kap.yaml_load('statefulset-resize-controller/manifests/operator/' + params.manifest_version + '/role_binding.yaml'));
local deployment = std.parseJson(kap.yaml_load('statefulset-resize-controller/manifests/operator/' + params.manifest_version + '/deployment.yaml'));


local image = params.images.operator.registry + '/' + params.images.operator.repository + ':' + params.images.operator.version;
local syncImage = params.images.rsync.registry + '/' + params.images.rsync.repository + ':' + params.images.rsync.version;

local controller_args = [
  '--sync-image',
  syncImage,
  '--sync-cluster-role',
  params.sync_cluster_role,
];

local sync_cluster_role_clusterrolebinding =
  if params.sync_cluster_role != '' then
    kube.ClusterRoleBinding(service_account.metadata.name + '-sync-cluster-role') {
      roleRef: {
        apiGroup: 'rbac.authorization.k8s.io',
        kind: 'ClusterRole',
        name: params.sync_cluster_role,
      },
      subjects: [
        {
          kind: 'ServiceAccount',
          name: service_account.metadata.name,
          namespace: params.namespace,
        },
      ],
    };

local objects = [

  role {
    metadata+: {
      name: prefix + super.name,
    },
  },
  role_binding {
    metadata+: {
      name: prefix + super.name,
    },
    roleRef+: {
      name: prefix + super.name,
    },
    subjects: std.map(function(s) s {
      name: prefix + super.name,
      namespace: params.namespace,
    }, super.subjects),
  },
  sync_cluster_role_clusterrolebinding,
  service_account,
  deployment {
    metadata+: {
      name: prefix + super.name,
    },
    spec+: {
      template+: {
        spec+: {
          serviceAccountName: prefix + super.serviceAccountName,
          containers: [
            if c.name == 'manager' then
              c {
                image: image,
                args: controller_args,
                resources+: params.operator.resources,
              }
            else
              c
            for c in super.containers
          ],
        },
      },
    },
  },
];

{
  '00_namespace': kube.Namespace(params.namespace),
}
+
std.foldl(
  function(obj, it) obj + it,
  [
    {
      ['10_' + std.asciiLower(obj.kind)]+: [
        obj {
          metadata+: {
            namespace: params.namespace,
          },
        },
      ],
    }
    for obj in std.filter(
      function(it) it != null,
      objects
    )
  ],
  {}
)
