AssetsManagerEx

第一次登陆：
[initManifests](manifestUrl)
_localManifest 创建、解析 
_tempManifest 创建 
_remoteManifest 创建

[update]() ----downloadversion -> parseversion -> downloadManifest(remote) [save as tempPath]->parseManifest()[use remoteManifest to parse]->download assets
如果下载失败，则会保存temp文件，以便于下次下载此文件
如果下载成功，则会把temp文件改成正式文件，用作以后登陆时的本地manifest

第二次登陆：
[initManifests](manifestUrl)
_localManifest 创建、解析

1、第一次没有下载完全 
_tempManifest 创建， 加载.temp文件解析
_remoteManifest 创建

[update]() ----downloadversion -> parseversion -> downloadManifest(remote) [save as tempPath]->parseManifest()[use remoteManifest to parse]->download assets

2、第一次下载成功，步骤和第一次登陆完全一样


