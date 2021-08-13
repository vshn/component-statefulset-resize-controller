local kap = import 'lib/kapitan.libjsonnet';
local inv = kap.inventory();
local params = inv.parameters.statefulset_resize_controller;
local argocd = import 'lib/argocd.libjsonnet';

local app = argocd.App('statefulset-resize-controller', params.namespace);

{
  'statefulset-resize-controller': app,
}
