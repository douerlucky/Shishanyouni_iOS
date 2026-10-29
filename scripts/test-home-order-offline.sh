#!/bin/zsh
# 只在 macOS 上验证首页排序与持久化，不启动模拟器，不执行触摸手势。
set -eu
cd "${0:A:h:h}"
binary="$(mktemp -t shishanyouni-home-order)"
trap 'rm -f "$binary"' EXIT
xcrun swiftc -parse-as-library -swift-version 5 -D HOME_ORDER_OFFLINE_TESTS \
  shishanyouni/HomeView/Components/HomeLayer.swift \
  shishanyouniTests/HomeFeatureOrderTests.swift -o "$binary"
"$binary"
