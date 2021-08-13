// main template for statefulset-resize-controller
local kap = import 'lib/kapitan.libjsonnet';
local kube = import 'lib/kube.libjsonnet';
local inv = kap.inventory();
// The hiera parameters for the component
local params = inv.parameters.statefulset_resize_controller;

// Define outputs below
{
}
