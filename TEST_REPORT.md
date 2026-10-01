# 原型验证记录

验证引擎：Godot 4.6.3-stable official，Compatibility。当前记录为 2026-10-01 的构建与云桌面图形实操检查。headless、真实渲染和手动输入分别记录。

## 已通过

- 全部 12 个环境GLB和4角色GLB导入、GDScript解析
- 六场景出生点经90物理帧后全部稳定落地
- 4角色每个idle/walk/run均可被AnimationPlayer识别，按循环播放
- 全部8个直接场景往返传送落地，没有重叠角色
- 暂停后位置漂移0；4角色切换后位置与相机yaw不变、visual子节点始终为1
- 真实CharacterBody物理路径：操场出生→西南出口→返回→北校舍入口；走廊与楼梯上/下；教室讲台绕行、窗侧窄道、后排与入口；部室桌右侧、标本与返回；两住宅入口坡道、客厅/茶席、餐厨/缘侧
- 以上路线终点平面误差均<0.12m，落地正常
- 损坏存档club=[90,0,90]在恢复检查后安全回默认spawn
- 当前中文与符号字形覆盖检查：缺字0
- Web单线程与Linux x86_64 release导出成功，无ERROR/WARNING
- 脚本隐私扫描：无网络请求、SDK或身份标识；事件仅本地存储

## 真实图形与手动输入已通过

- 从实际 Godot 窗口选择千反田，W步行、Shift奔跑横穿操场，E进入教学楼
- 步行至普通教室门口、进入、绕讲台、E观察黑板；弹窗中文字完整，观察记录+1
- Esc关闭观察窗，按原路回走廊、进入部室；过渡稳定
- 部室鼠标视角、滚轮缩放、Esc暂停/鼠标释放正常
- 六景真实渲染检查修正了首轮过曝、未烘焙材质白色、走廊门缝视角、近镜头角色遮挡和HUD低对比
- 相机五条射线检查视觉层与运动碰撞层，过近时隐藏角色；简化碰撞不再造成相机穿过门框
- 最新统一六景及菜单截图见交付包 artifacts/screenshots_final；早期截图不作为验收依据

## 未验证 / 限制

- Web浏览器实际运行及GitHub Pages URL：等待部署与浏览器测试
- macOS/Windows原生构建：未导出和运行
- 手机触屏：未实现控制，不列为目标
- 性能未针对低端设备基准测试

## 复跑

参见 tests/REVIEW_TESTS.md。始终使用隔离XDG_DATA_HOME，避免影响现有游玩进度。

- godot --headless --path . -- --smoke
- godot --headless --path . --script res://tests/review_regressions.gd
- godot --headless --path . --script res://tests/review_routes.gd

本地完整日志位于交付包 artifacts/test-logs/（不纳入公开仓库）。

## 干净源码发行验证

另建独立目录，从源码快照排除所有 `.import` 与 `.godot` 后，用 Godot 4.6.3 重新导入。17个导入描述文件均自动生成，与本地原配置比较仅随机资源UID不同，所有导入参数完全相同。项目场景引用使用资源路径，脚本 `.gd.uid` 保留。四角色 idle/walk/run、六景落地烟测通过，Web release 导出成功，全部阶段无ERROR/WARNING。源码仓库不跟踪自动 `.import`，原工程本地文件仍保留。
