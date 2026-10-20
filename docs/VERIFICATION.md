# 已执行的验证与边界

- B：14组源码相关状态模型，覆盖两份独立存档、新游戏、切回旧存档、复数卡、购买失败、最后一张、区域卸载、附近/超距和无首胜。
- A/B：在另一中文目录的模拟游戏安装中，分别安装23文件并校验SHA256，再成功卸载23文件。安装器不含作者电脑路径，也不需要作者的存档/清单。
- 提取的标记行为：修改前，买齐后卸载区域仍重新提示、没有HUD钩子；修改后，核实为0保持隐藏并接入HUD刷新；对副本实际执行回滚后输出与修改前一致。
- 两文件累计差异可字节级重建；回滚副本哈希与修改前一致。
- XML解析、源码结构及本机原生接口名称检查通过。

这些不是游戏引擎编译、游戏中存档读写持久化、真实商店交易或画面验收。B修复版已由本机用户反馈可以运行，但动态小地图画面、交易事件时序与跨存档持久化仍待逐项实机验收，故保留预览标记。不能保证所有补丁、系统、平台或Mod组合可用。

可用Python3重复离线状态模型检查：
```text
python tests/probe_store_minimap.py variants/B/release/mods/modGwentPlayersMap/content/scripts/local/gwm.ws tests/fixtures.json
```

这只是源码相关的简化模型，不是WitcherScript执行器。公开仓库未包含作者私人存档和原始日志。

## local.3-hotfix.1 增量验证

- 实际旧B编译报错：第941、950、1014行找不到 `StringToName`；使用固定 `name` 字面量表修复，没有要求玩家修改存档。
- 同输入源码检查：修复前检查发现三处调用、退出1；修复后两个标签表各覆盖91个地点、无重复、名称保持一致、退出0；在独立副本实际回滚后重现三处调用、退出1，恢复哈希与修复前一致。此检查不是游戏编译器。
- 修复后14组原有离线状态模型全部通过；累计补丁字节级重建脚本与菜单文件成功；本机安装回执23文件哈希复核通过。
- 2026-10-20，本机玩家在自己启动后反馈“可以了”。这是用户确认可运行，不是代理完整录制的游戏流程，也不代表全部功能或所有补丁兼容。

复核本次名称表（Python3，仓库根目录）：
```text
python tests/probe_name_tags.py variants/B/release/mods/modGwentPlayersMap/content/scripts/local/gwm.ws variants/B/release/mods/modGwentPlayersMap/content/scripts/local/gwm_data.ws
```
