import json


cmds = []

with open('/tmp/etcd.json') as f:
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
    cmds.append(docker_config["Config"]["Image"].replace("3.5.3","3.5.6"))

    api_server_args = []
    for args in docker_config['Args']:
        api_server_args.append(args)

    cmds.extend(api_server_args)

print (" ".join(cmds))