[app]
title = VND Converter
package.name = vndconverter
package.domain = org.example
source.dir = .
source.include_exts = py,kv,png,jpeg
source.exclude_dirs = .git,bin,dist,__pycache__
source.exclude_patterns = *.pyc
version = 0.1
# 添加必要的依赖（如 kivy.deps 可选）
requirements = python3,kivy==2.1.0,requests==2.28.2,openssl
orientation = portrait
fullscreen = 1
icon = ./assets/icon.jpeg
# 添加更多权限（如需要访问存储）
android.permissions = INTERNET
# 确保 API 与 build-tools 版本匹配
android.api = 31
android.ndk = 25.1.8937393  
android.sdk = 31
android.build_tools = 30.0.3
android.archs = arm64-v8a
android.strip_debug = 1

[buildozer]
log_level = 2  warn_on_root = 1

# 如果手动下载 SDK/NDK，可指定本地路径（需与 CI 环境一致）
# android.sdk_path = /home/runner/.android/sdk
# android.ndk_path = /home/runner/.android/sdk/ndk/25.1.8937393