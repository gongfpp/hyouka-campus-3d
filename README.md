# 冰菓：放课后的神山

Godot 4.6.3 / Compatibility 非商业同人校园探索原型。独立工程，不依赖 Iscream。

## 游玩

- WASD 移动，Shift 奔跑；鼠标转视角，滚轮调整第三人称距离
- E 观察/进入，J 地点手记，C 切换角色，Esc 菜单并释放鼠标
- 从操场向北走到教学楼入口，按 E 到走廊。走廊两侧可进入教室、地学准备室；每处入口可返回
- 西南侧「放课后出校」可访问千反田家、折木家，住宅入口可返回校园
- 楼梯可步行登上平台，未开放区域不提供虚假的可进入门洞
- 四人均有独立模型与 idle/walk/run 动画，切换保留位置与观察手记
- 进度自动存到本设备；损坏存档安全回退。没有已实现的推理主线

## 启动 / 导出

用 Godot 4.6.3 打开 project.godot，按 F6/F5 运行。Linux 构建直接运行 build/linux/hyouka.x86_64。Web 构建必须从 HTTP(S) 提供，不能双击 file://。

导出说明见 tools/EXPORT.md。GitHub Pages 工作流在 main 分支推送后构建并部署 Web 单线程版本。仓库 Pages 的 Source 应设置为 GitHub Actions。WebGL2 桌面浏览器为目标，手机触摸控制尚未实现。

```sh
godot --headless --editor --import --path . --quit
godot --headless --path . -- --smoke
GODOT_TEMPLATE_DIR=/path/to/4.6.3.stable bash tools/export.sh Web
GODOT_TEMPLATE_DIR=/path/to/4.6.3.stable bash tools/export.sh Linux
```

## 范围和素材

六处场景以动画已展示画面为视觉依据；全校园连接、楼梯、隐藏区域与住宅内外连接为游玩设计推定，不声称精密一比一复刻。当前游戏资产采用适合实时运行的合并网格与简化碰撞，程序材质未完全烘焙，因此与高采样 Blender 展示图有差异。

模型为本任务原创重建；角色/原作权利属于各权利方。项目为非官方非商业同人研究原型，不表示获得官方授权，不随包传播动画截图。中文字体为 Noto Sans CJK SC 子集，SIL OFL 1.1，版权/许可证见 assets/fonts/LICENSE.txt。字体子集仅包含当前UI字符，增改中文文本后需重新生成。

## 隐私

没有联网埋点、身份标识或第三方分析SDK。只在 user://events.json 保留最多200条本地场景进入、角色选择、观察、加载/恢复错误事件。无坐标、账号或个人信息。菜单可清空该记录。进度另存 user://progress.json。

## 验证

烟测与独立真实物理路线测试在 tests/。headless只验证逻辑/物理，不等同视觉验收；最终验证记录另见 TEST_REPORT.md。开发参数 --capture-tour 可从真实渲染窗口保存六景截图到 artifacts/screenshots_final/。
