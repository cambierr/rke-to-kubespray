import json
import sys

cmds = []
current_etcd_node = []

if len(sys.argv) !=3:
    sys.exit(0)
current_etcd_node.append("https://"+sys.argv[1]+":2379")
current_etcd_node.append("https://"+sys.argv[2]+":2379")


with open('/tmp/apiserver.json') as f:
    docker_config = json.load(f)[0]
    cmds.append("docker")
    cmds.append("run")
    if docker_config['Config']['AttachStdin']:
        cmds.append('-i')
    if docker_config['Config']['AttachStdout'] or docker_config['Config']['AttachStderr']:
        cmds.append('-t')
    else:
        cmds.append('-d')
    if docker_config['HostConfig']['AutoRemove']:
        cmds.append('--rm')
    
    name = docker_config['Name']
    if name and name[0]:
        name = name[1:]
    cmds.extend(['--name', name])
    cmds.extend(['--entrypoint', docker_config['Path']])
    cmds.extend(['--net', docker_config['HostConfig']['NetworkMode']])
    cmds.extend(['--restart', docker_config['HostConfig']['RestartPolicy']['Name']])

    ipc_mode = docker_config['HostConfig']['IpcMode']
    if ipc_mode and ipc_mode != 'private':
        cmds.extend(['--ipc', docker_config['HostConfig']['IpcMode']])
    if docker_config['HostConfig']['PidMode']:
        cmds.extend(['--pid', docker_config['HostConfig']['PidMode']])
    if docker_config['HostConfig']['Privileged']:
        cmds.append('--privileged')

    container_envs = docker_config['Config']['Env'] or {}
    for env in set(container_envs):
        if ' ' in env:
            cmds.extend(['-e', '"{}"'.format(env)])
        else:
            cmds.extend(['-e', env])
    for mount in docker_config['Mounts'] or []:
            if mount["Type"] == "bind":
                cmds.extend(['--mount', "type=bind,src="+mount["Source"]+",dst="+mount["Destination"]])
    volumes_from = docker_config['HostConfig']['VolumesFrom'] or {}
    for volume in volumes_from:
        cmds.extend(['--volumes-from',volume])
    cmds.append(docker_config["Config"]["Image"])

    api_server_args = []
    for args in docker_config['Args']:
        if not args.startswith('--service-account-issuer=') and not args.startswith('--api-audiences=') and not args.startswith('--etcd-servers=') and not args.startswith('--anonymous-auth='):
            api_server_args.append(args)

    # Add the rke migration specifics
    api_server_args.append("--api-audiences=unknown,https://kubernetes.default.svc.cluster.local")
    api_server_args.append("--service-account-issuer=rke")
    api_server_args.append("--service-account-issuer=https://kubernetes.default.svc.cluster.local")
    api_server_args.append("--etcd-servers="+",".join(current_etcd_node))
    api_server_args.append("--enable-bootstrap-token-auth=True")
    api_server_args.append("--anonymous-auth=true")
    cmds.extend(api_server_args)

print (" ".join(cmds))