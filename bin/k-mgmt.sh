#!/bin/sh

set -eu

export OPSCTL_GITHUB_TOKEN="$(cat /secrets/opsctl-github-token)"
eval `ssh-agent -s` > /dev/null 2>&1
ssh-add ~/.ssh/giantswarm_rsa > /dev/null 2>&1

NAME="k-mgmt.sh"

DIRECTORY="/tmp/gs-clusters"
CONTROL_PLANE_LIST=$DIRECTORY/control-planes

function notify {
  level=${1:-""}
  if [[ $level == "" ]]; then
    return 1
  fi


  message=${2:-""}
  if [[ $message == "" ]]; then
    return 1
  fi

  echo $message
  
  if [ $level == "normal" ]; then
    notify-send --urgency normal "$message"
  fi
  if [ $level == "critical" ]; then
    notify-send --urgency critical "$message"
  fi
}

function help_message {
  echo "$NAME - A tool for managing Giant Swarm kubeconfigs"
  echo "  --build-cluster-lists to build cluster lists (used for determining installations, and dmenu integration)"
  echo "  --print-cluster-lists to print cluster lists"
  echo "  --help to show this text message"
  echo "  [cluster-id] to ensure kubeconfig for that cluster is set"
}

function build_cluster_lists {
  echo "Building cluser lists"

  ensure_directory
  build_control_plane_list
  build_tenant_cluster_lists

  echo "Built cluster lists"
}

function print_cluster_lists {
  cat $DIRECTORY/* | uniq | sort
}

function ensure_directory {
  echo "Ensuring directory $DIRECTORY to hold cluster lists exists"
 
  if [[ ! -d $DIRECTORY ]]; then
    echo "Directory $DIRECTORY does not exist, creating"
    mkdir -p $DIRECTORY
  else
    echo "Directory $DIRECTORY does exist, not creating"
  fi

  echo "Ensured directory $DIRECTORY to hold cluster lists exists"
}

function build_control_plane_list {
  echo "Building control plane list"

  echo "Checking if old control plane list exists"
  if [[ -f $CONTROL_PLANE_LIST ]]; then
    echo "Removing old control plane list"
  fi

  opsctl list installations --short | tr " " "\n" > $CONTROL_PLANE_LIST

  echo "Built control plane list"
}

function build_tenant_cluster_lists {
  echo "Building tenant cluster lists"

  for installation in $(opsctl list installations --short); do
    build_tenant_cluster_list $installation
  done

  echo "Built tenant cluster lists"
}

function build_tenant_cluster_list {
  installation=${1:-""}
  if [[ $installation == "" ]]; then
    return 1
  fi

  echo "Building tenant cluster list for $installation"

  tenant_cluster_list=$DIRECTORY/$installation
  echo "Checking if old tenant cluster list for $installation exists"
  if [[ -f $tenant_cluster_list ]]; then
    echo "Removing old tenant cluster list for $installation"
    rm $tenant_cluster_list
  fi

  echo "Fetching tenant cluster IDs"
  gsctl list clusters --endpoint=$installation | tail -n +2 | awk '{print $1}' > $tenant_cluster_list

  echo "Built tenant cluster list for $installation"
}

function id_is_for_control_plane {
  cluster_id=${1:-""}
  if [[ $cluster_id == "" ]]; then
    return 1
  fi

  notify "normal" "Checking if ID is for a control plane"

  if grep -Fxq $cluster_id $CONTROL_PLANE_LIST; then
    notify "normal" "ID is for a control plane"
    return 0
  fi

  notify "normal" "ID is not for a control plane"
  return 1
}

function id_is_for_tenant_cluster {
  cluster_id=${1:-""}
  if [[ $cluster_id == "" ]]; then
    return 1
  fi

  notify "normal" "Checking if ID is for a tenant cluster"

  for cluster_list in $DIRECTORY/*; do
    if [[ $cluster_list == $CONTROL_PLANE_LIST ]]; then
      continue
    fi

    if grep -Fxq $cluster_id $cluster_list; then
      notify "normal" "ID is for a tenant cluster"
      return 0
    fi
  done

  notify "normal" "ID is not for a tenant cluster"
  return 1
}

function kubeconfig_exists {
  cluster_id=${1:-""}
  if [[ $cluster_id == "" ]]; then
    return 1
  fi

  notify "normal" "Checking if kubeconfig exists for $cluster_id"

  if kubectl config get-contexts giantswarm-$cluster_id; then
    notify "normal" "Kubeconfig exists for $cluster_id"
    return 0
  fi

  notify "critical" "Kubeconfig does not exist for $cluster_id"
  return 1
}

function kubeconfig_works {
  cluster_id=${1:-""}
  if [[ $cluster_id == "" ]]; then
    return 1
  fi

  noify "normal" "Checking if kubeconfig works for $cluster_id"

  if kubectl --context=giantswarm-$cluster_id cluster-info; then
    notify "normal" "Kubeconfig works for $cluster_id"
    return 0
  fi

  notify "critical" "Kubeconfig does not work for $cluster_id"
  return 1
}

function set_kubeconfig {
  cluster_id=${1:-""}
  if [[ $cluster_id == "" ]]; then
    return 1
  fi

  notify "normal" "Setting kubeconfig for $cluster_id"

  kubectl config use-context giantswarm-$cluster_id 

  notify "normal" "Set kubeconfig for $cluster_id"
}

function create_control_plane_kubeconfig {
  cluster_id=${1:-""}
  if [[ $cluster_id == "" ]]; then
    return 1
  fi

  notify "normal" "Creating kubeconfig for control plane $cluster_id"

  output=$(/home/joe/go/src/github.com/giantswarm/opsctl/opsctl create kubeconfig -c $cluster_id --user=joe)
  if [ $? -eq 0 ]; then
    notify "normal" "Created kubeconfig for control plane $cluster_id"
  else
    notify "critical" "Failed creating kubeconfig for control plane $cluster_id: $output"
  fi
}

function create_tenant_cluster_kubeconfig {
  cluster_id=${1:-""}
  if [[ $cluster_id == "" ]]; then
    return 1
  fi

  notify "normal" "Searching for installation for tenant cluster $cluster_id"
  installation=""
  for cluster_list in $DIRECTORY/*; do
    if [[ $cluster_list == $CONTROL_PLANE_LIST ]]; then
      continue
    fi

    if grep -Fxq $cluster_id $cluster_list; then
      installation=$(basename $cluster_list)
      notify "normal" "Found installation $installation for tenant cluster $cluster_id"
    fi
  done

  if [[ $installation == "" ]]; then
    notify "critical" "Could not find installation for $cluster_id"
    return 1
  fi

  notify "normal" "Creating kubeconfig for tenant cluster $cluster_id"

  
  output=$(/home/joe/go/src/github.com/giantswarm/gsctl/gsctl create kubeconfig \
      --endpoint=$installation \
      --cluster=$cluster_id \
      --certificate-organizations=system:masters \
      --ttl=12h)
  if [ $? -eq 0 ]; then
    notify "normal" "Created kubeconfig for tenant cluster $cluster_id"
  else
    notify "critical" "Failed creating kubeconfig for tenant cluster $cluster_id"
  fi
}

function ensure_kubeconfig {
  cluster_id=${1:-""}
  if [[ $cluster_id == "" ]]; then
    return 1
  fi

  notify "normal" "Ensuring kubeconfig for cluster with ID $cluster_id"

  notify "normal" "Checking if we need to create a new kubeconfig for cluster with ID $cluster_id"
  if kubeconfig_exists $cluster_id && kubeconfig_works $cluster_id; then
    set_kubeconfig $cluster_id
    return 0
  fi

  if id_is_for_control_plane $cluster_id; then
    create_control_plane_kubeconfig $cluster_id
    return 0
  fi

  if id_is_for_tenant_cluster $cluster_id; then
    create_tenant_cluster_kubeconfig $cluster_id
    return 0
  fi

  notify "critical" "Could not ensure kubeconfig"
  return 1
}

function main {
  if [[ $arg == "--help" || $arg == "" ]]; then
    help_message
    exit 0
  fi

  if [[ $arg == "--build-cluster-lists" ]]; then
    build_cluster_lists
    exit 0
  fi

  if [[ $arg == "--print-cluster-lists" ]]; then
    print_cluster_lists
    exit 0
  fi

  ensure_kubeconfig $arg 
}

arg=${1:-""}
main $arg
