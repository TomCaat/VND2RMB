[app]
title = VND Converter
package.name = vndconverter
package.domain = org.example
source.dir = .
source.include_exts = py,kv,png
source.exclude_dirs = .git,bin,dist,__pycache__
source.exclude_patterns = *.pyc
version = 0.1
requirements = python3,kivy==2.1.0,requests==2.28.2,openssl
orientation = portrait
fullscreen = 1
icon = ./assets/icon.jpeg
android.permissions = INTERNET
android.api = 31
android.ndk = 23b
android.sdk = 31
android.build_tools = 30.0.3
android.archs = arm64-v8a
android.strip_debug = 1

[buildozer]
log_level = 1
warn_on_root = 1