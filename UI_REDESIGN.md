# 放课后手册：UI 重设计

## 版本与边界

本次为独立 UI 小版本：本地基线 `0dadae8`，实现提交 `1569c2a752e22989b1e9dc376584684afbae86bf`，分支 `ui/editorial-redesign`。

发布从远端 `main` 的 `893e283c77dc10262da265da3c51929960774ece` 正常追加提交；远端与本地基线是内容对应、历史不同的发布链，不覆盖远端历史，也不把本地提交 SHA 当作线上版本。实际线上 SHA 以 Pages 的 `version.json` 及该 SHA 对应的 Actions 记录为准。

发布准备日期：2026-10-01 UTC。本文随 UI 源码提交；提交时自动构建与 Pages 部署结果待核验，不提前声称上线成功。角色与场景共 16 个 GLB、埋点脚本均与基线逐字节一致；独立场景还原分支不在本次发布范围。

## 可核验设计

- 纸色 `#F4F0E4`、墨绿 `#25473E`、次级文字 `#6D786C`、分隔线 `#C3C8B5`、焦点色 `#97734C`
- 主菜单是左侧文集页，保留右侧真实校园。大字标题、英文小字与序号形成排版层级，不使用原片截图作为背景
- 原 135px 通栏顶栏、65px 通栏底栏改为紧凑浮动地点卡、右侧进度卡、底部交互提示。按 H 展开 / 收起完整操作提示
- 同行者用四个既有角色 GLB 的真实 SubViewport 胸像，独立背景色、姓名、当前状态。横窗四列、竖窄窗两列；只渲染一次，无背景动画开销
- 观察手记使用双栏地点索引与已有观察记录标题；观察弹窗、旅行、暂停、关于、重置确认共享同一主题
- 所有按钮有明确 normal / hover / pressed / focus / disabled 样式。危险的“重新开始”默认焦点落在保留进度；Esc 可取消
- 菜单暂停人物物理与 AnimationPlayer。Esc 从子页返回调用来源；游戏中直接按 J/C 打开的页关闭后返回探索。快速重复开关不叠加节点
- `canvas_items + expand` 支持不同窗口比例，取消强制 16:9 黑边；字体继续使用本地 OFL Noto 子集，当前可显示文本缺字为 0

## 颜色管线补丁（独立于 UI 造型）

角色 GLB 的 `COLOR_0` 为合法的线性颜色。导入材质是 `Original_vertex_palette`，白色基底、vertex-color-as-albedo，roughness 0.85、metallic 0、double-sided。

本例肤色的 Godot 读取值为 `(0.9098, 0.5373, 0.3294)`，对应作者 sRGB `(0.96, 0.76, 0.61)` 的线性值。Compatibility 渲染器在 sRGB 空间工作，直接使用线性色导致肤色与暗色偏差。`vertex_color_is_srgb` 在 Compatibility 不生效。

`character_palette.gd` 仅对上述材质名应用实例级 ShaderMaterial；`character_palette.gdshader` 仅当 `OUTPUT_IS_SRGB` 时执行标准分段 linear → sRGB 传递函数。所有颜色一视同仁，保留 roughness / metallic / specular，不改原始 palette、几何或 GLB 字节。主场景和头像使用同一补丁。Forward+/Mobile 保留线性色路径。

官方依据：
- [Godot 4.6 BaseMaterial3D 顶点色开关限制](https://docs.godotengine.org/en/4.6/classes/class_basematerial3d.html#class-basematerial3d-property-vertex-color-is-srgb)
- [Godot Compatibility 顶点颜色问题记录](https://github.com/godotengine/godot/issues/87486)
- [Compatibility 的 sRGB 工作空间](https://godotengine.org/article/status-of-opengl-renderer/)
- [Godot 多分辨率与 expand](https://docs.godotengine.org/en/4.4/tutorials/rendering/multiple_resolutions.html)

不能把颜色修复称作人物建模提升。Blender 与 Godot 的光照、色调映射、导入量化仍有差异，需要同光照与无光照色块读回分别验证。

## 复跑

始终隔离 XDG_DATA_HOME / XDG_CONFIG_HOME / XDG_CACHE_HOME。

- `godot --headless --editor --path . --import --quit`
- `godot --headless --path . -- --smoke`
- `godot --headless --path . --script res://tests/review_ui.gd`
- `godot --headless --fixed-fps 60 --path . --script res://tests/review_regressions.gd`
- `godot --headless --fixed-fps 60 --path . --script res://tests/review_routes.gd`
- `bash tools/launch_ui_review.sh`：原生人工交互；开发参数下 F12 保存真实帧
- `bash tools/capture_final_ui.sh`：真实图形的同光照颜色对照、无光照色块读回以及 9 个窗口 / UI 状态截图，自动退出
- `GODOT_TEMPLATE_DIR=/path/to/4.6.3.stable bash tools/export.sh Web`

现有 mechanics / routes 测试仅增加显式 `_resume()`，以适应菜单现在真正暂停物理；路线与判定未修改。

## 已完成的检查

- Godot 4.6.3 Compatibility 全量导入，无脚本解析错误
- 六场景落地、四角色 idle/walk/run 烟测
- 六景路线、八处传送、原有角色切换与暂停回归：0 失败
- UI 12 轮菜单 / 手记 / 角色打开和分级返回，背景位置与动画冻结，角色选择保位置，重置取消，提示收起 / 展开，鼠标真实 Viewport 命中测试：0 失败
- 1280×720、800×900、1600×600 面板不越界；窄窗真实图初轮发现高度浪费，已增加双排所需高度
- 中文可显示字符串字体覆盖：缺字 0
- 所有 GLB 与 `telemetry.gd` 对比基线逐字节一致
- Web release 本地导出成功，无 ERROR / WARNING。它不等于网页实际运行验收

真实初轮截图在 `artifacts/ui-redesign/`；最终颜色补丁与窄窗修正的图形验收另存 `artifacts/ui-redesign/final/`，用日志与哈希清单关联，不覆盖初轮。

## 当前限制

本次提交进入既有 GitHub Actions → Pages 发布流程；构建、部署与线上版本需要对应同一远端 SHA 核验。实际浏览器运行、网页 pointer lock / resize / 字体加载等仍需针对该 SHA 的导出文件另测。没有以原生图形截图或 export 成功代替 Web 验收。未测试 macOS / Windows 原生版与手机触屏。

## 最终图形与颜色验收

实际运行：Godot 4.6.3-stable，Compatibility，Mesa 25.0.7 llvmpipe / LLVM 19.1.7。原生窗口实图为 1180×812，另测 800×900 窄窗与 1600×600 宽窗。截图均来自该分支真实运行帧，不是概念图。

颜色证据位于 `artifacts/ui-redesign/final/`：
- `color-original-neutral.png` / `color-corrected-neutral.png`：同模型、同机位、同中性光照对照，肤色及眼睛/头发/制服一并比较
- `chip-original.png` / `chip-corrected.png`：无光照色块，排除灯光和材质粗糙度
- `color-readback.json`：原始屏幕RGB `(0.909804,0.537255,0.329412)`；修正后 `(0.960784,0.760784,0.611765)`，与作者的 sRGB `(0.96,0.76,0.61)` 每通道误差小于 1/255

最终材质只执行颜色空间传递，不修改法线或灯光。初轮误加的背面法线处理已撤回；最终图保留原来的平滑受光。

最终图形运行无脚本或着色器 ERROR。云软件驱动不支持更改 V-Sync 的环境 WARNING 仍存在，不代表 Web 或性能验收。
