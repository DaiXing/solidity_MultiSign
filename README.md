# solidity_MultiSign
多签钱包

owner列表，包含多个人，都是owner

添加owner，移除owner，动态调整

一个转账任务，需要多个owner签署才能生效。

如果owner签署数量达到阙值，则任务成功，可以执行。

否则，任务取消。

## 安装依赖
forge install foundry-rs/forge-std

## 运行单测 
切换到项目目录

执行命令 forge test  -vvvvv

